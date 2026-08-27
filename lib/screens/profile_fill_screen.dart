import 'dart:developer' show log;
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hooper/models/player_profile.dart';
import 'package:hooper/widgets/skeleton_widget.dart';
import 'package:image_picker/image_picker.dart';

import '../data/providers.dart';

const int kMinimumAge = 18;

enum SubmitState { yes, no, verifying, saving }

class ProfileFillScreen extends ConsumerStatefulWidget {
  const ProfileFillScreen({super.key});

  @override
  ConsumerState<ProfileFillScreen> createState() => _DateOfBirthScreenState();
}

class _DateOfBirthScreenState extends ConsumerState<ProfileFillScreen> {
  DateTime? _selectedDate;
  String? _error;
  final heightController = TextEditingController();
  final displayNameController = TextEditingController();
  final bioController = TextEditingController();
  Set<PlayerPosition> _selectedPosition = {PlayerPosition.forward};
  SubmitState submitState = SubmitState.no;
  XFile? profileImage;
  XFile? bannerImage;

  int _ageOn(DateTime date, DateTime now) {
    int age = now.year - date.year;
    if (now.month < date.month || (now.month == date.month && now.day < date.day)) {
      age--;
    }
    return age;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - kMinimumAge, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year - kMinimumAge, now.month, now.day),
      helpText: 'Date of birth',
    );
    if (picked != null) {
      setState(() {
        submitState = SubmitState.yes;
        _selectedDate = picked;
        _error = null;
      });
    }
  }

  String get inputName => displayNameController.text.trim().toLowerCase();

  void setErrorCantPush(String error) {
    setState(() {
      _error = error;
      submitState = SubmitState.no;
    });
  }

  Future<void> _submit() async {
    final date = _selectedDate;
    setState(() => submitState = SubmitState.verifying);

    int? height = int.tryParse(heightController.text);
    if (date == null) {
      setErrorCantPush("Please enter an age. ");
      return;
    }
    if (_ageOn(date, DateTime.now()) < kMinimumAge) {
      setErrorCantPush('You must be $kMinimumAge or older.');
      return;
    }
    if (height == null) {
      setErrorCantPush('Please enter a height. ');
      return;
    }
    if (height > 300 || height < 100) {
      setErrorCantPush('You must be between 100 and 300cm.');
      return;
    }
    if (inputName.length < 5) {
      setErrorCantPush('Please enter a valid name with at least 5 characters.');
      return;
    }

    final uniqueAsync = ref.read(isUniqueNameProvider(inputName));

    uniqueAsync.when(
      data: (exists) {
        if (!exists) {
          setState(() {
            _error = "Username already taken. ";
            submitState = SubmitState.yes;
          });
          _pushSubmit(height, date, bioController.text.trim(), inputName);
        } else {
          setState(() {
            _error = '';
            submitState = SubmitState.no;
          });
        }
      },
      error: (Object error, StackTrace stackTrace) {
        setState(() {
          _error = "Something went wrong. ";
          submitState = SubmitState.no;
        });
      },
      loading: () {
        setState(() {
          submitState = SubmitState.verifying;
        });
      },
    );

    setState(() {
      _error = null;
    });
  }

  Future<void> _requestLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _error = permission == LocationPermission.deniedForever
              ? 'Location is off in Settings — you can turn it on later from your Profile.'
              : 'Location permission was denied. You can grant it later from your Profile.';
        });
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (!mounted) return;
        setState(() => _error = 'Turn on location services and try again.');
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      final uid = ref.read(currentUserIdProvider);
      await ref
          .read(playerProfileRepositoryProvider)
          .updateLocation(uid, GeoPoint(position.latitude, position.longitude));
      if (!mounted) return;
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not get your location: $e');
    } finally {}
  }

  void _pushSubmit(int height, DateTime date, String bio, String name) async {
    setState(() => submitState = SubmitState.saving);
    try {
      final uid = ref.read(currentUserIdProvider);
      await _requestLocation();
      await FirebaseFirestore.instance.collection('playerProfiles').doc(uid).update({
        'height': height,
        'position': playerPositionToInt(_selectedPosition.first),
        'bio': bio,
        'displayName': name,
      });
      await FirebaseFirestore.instance.collection('usernames').doc(name).set({});
      await FirebaseFirestore.instance.collection('users').doc(uid).update({'dateOfBirth': Timestamp.fromDate(date)});

      Future.wait([
        _pushImage(propertyName: 'photoUrl', uid: uid, image: profileImage),
        _pushImage(propertyName: 'bannerUrl', uid: uid, image: bannerImage),
      ]);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not save your birthday. Please try again.');
      log(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          submitState = SubmitState.yes;
        });
      }
    }
  }

  Future<void> _pushImage({required String uid, required String propertyName, required XFile? image}) async {
    if (image == null) return;

    final file = File(image.path);

    final storageRef = FirebaseStorage.instance.ref().child('${propertyName}s').child('$uid.jpg');
    final uploadTask = await storageRef.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    final downloadUrl = await uploadTask.ref.getDownloadURL();

    await FirebaseFirestore.instance.collection('playerProfiles').doc(uid).update({propertyName: downloadUrl});
  }

  @override
  Widget build(BuildContext context) {
    final bool canEdit = !(submitState == SubmitState.saving || submitState == SubmitState.verifying);
    final uniqueAsync = ref.watch(isUniqueNameProvider(inputName.length < 5 ? "New Player" : inputName));

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Set up your profile", textAlign: TextAlign.center),
            OutlinedButton(
              onPressed: canEdit ? _pickDate : null,
              child: Text(
                _selectedDate == null
                    ? 'Select date of birth'
                    : '${_selectedDate!.month}/${_selectedDate!.day}/${_selectedDate!.year}',
              ),
            ),
            SegmentedButton<PlayerPosition>(
              segments: [
                ButtonSegment(value: PlayerPosition.guard, label: Text("Guard"), enabled: canEdit),
                ButtonSegment(value: PlayerPosition.forward, label: Text("Forward"), enabled: canEdit),
                ButtonSegment(value: PlayerPosition.center, label: Text("Center"), enabled: canEdit),
              ],
              selected: _selectedPosition,
              onSelectionChanged: (set) => setState(() => _selectedPosition = set),
            ),
            TextField(
              controller: heightController,
              keyboardType: TextInputType.number,
              enabled: canEdit,
              onChanged: (_) => setState(() {
                submitState = SubmitState.yes;
                _error = '';
              }),
            ),
            TextField(
              controller: displayNameController,
              enabled: canEdit,
              onChanged: (_) {
                setState(() {
                  _error = '';
                });
              },
            ),
            FilledButton(
              child: Text("Log out"),
              onPressed: () {
                FirebaseAuth.instance.signOut();
                GoogleSignIn.instance.signOut();
              },
            ),
            inputName.length >= 5
                ? SkeletonWidget<bool>(
                    val: uniqueAsync,
                    dummyData: true,
                    builder: (bool exists) {
                      if (!exists) {
                        return Text("$inputName is available. ");
                      } else {
                        return Text("$inputName is already taken. ");
                      }
                    },
                  )
                : const SizedBox(),
            TextField(
              controller: bioController,
              enabled: canEdit,
              onChanged: (_) {
                setState(() {
                  submitState = SubmitState.yes;
                  _error = '';
                });
              },
            ),
            Row(
              children: [
                Column(
                  children: [
                    FilledButton(
                      child: Text("Upload pfp"),
                      onPressed: () async {
                        final picker = ImagePicker();

                        profileImage = await picker.pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 512,
                          maxHeight: 512,
                          imageQuality: 50,
                        );
                        setState(() {});
                      },
                    ),
                    Text(profileImage == null ? "No pfp selected" : "PFP selected"),
                  ],
                ),
                Column(
                  children: [
                    FilledButton(
                      child: Text("Upload banner photo"),
                      onPressed: () async {
                        final picker = ImagePicker();

                        bannerImage = await picker.pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 1080,
                          maxHeight: 1080,
                        );

                        setState(() {});
                      },
                    ),
                    Text(profileImage == null ? "No banner image selected" : "Banner selected"),
                  ],
                ),
              ],
            ),
            if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            FilledButton(
              onPressed: submitState == SubmitState.no ? null : _submit,
              child: switch (submitState) {
                SubmitState.yes => Text("Submit"),
                SubmitState.no => Text("Fix any errors before submitting. "),
                SubmitState.verifying => const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SubmitState.saving => const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}
