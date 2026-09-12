import 'dart:developer' show log;
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hooper/core/utils/date_formatter.dart';
import 'package:hooper/core/widgets/background_image.dart';
import 'package:hooper/core/widgets/blurred_container.dart';
import 'package:hooper/core/widgets/blurred_text_field.dart';
import 'package:hooper/core/widgets/dark_buttons.dart';
import 'package:hooper/core/widgets/skeleton_widget.dart';
import 'package:hooper/features/profile/data/player_profile.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/providers.dart';
import '../../../core/widgets/position_picker.dart';

const int kMinimumAge = 18;

enum SubmitState { yes, verifying, saving }

enum NameState { valid, invalid, verifying }

class ProfileFillScreen extends ConsumerStatefulWidget {
  const ProfileFillScreen({super.key});

  @override
  ConsumerState<ProfileFillScreen> createState() => _ProfileFillScreenState();
}

class _ProfileFillScreenState extends ConsumerState<ProfileFillScreen> {
  FormData data = FormData();

  Future<void> _submit() async {
    final date = data.birthday;
    setState(() => data.currState = .verifying);
    final pass = data.bannerImage != null && data.profileImage != null && formKey.currentState!.validate();
    if (!pass) return;

    final inputName = data.username!;
    final isTaken = await ref.read(isNameTakenProvider(inputName).future);

    if (!isTaken) {
      _pushSubmit(data.height!, date!, data.bio?.trim() ?? "", inputName);
    }
  }

  Future<void> _requestLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == .denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == .denied || permission == .deniedForever) {
        if (!mounted) return;
        setState(() {
          data.generalError = permission == .deniedForever
              ? 'Location is off in Settings. '
              : 'Location permission was denied. ';
        });
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (!mounted) return;
        setState(() => data.generalError = 'Turn on location services and try again.');
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      final uid = ref.read(currentUserIdProvider);
      final profileRepo = ref.read(playerProfileRepositoryProvider);
      await profileRepo.updateLocation(uid, GeoPoint(position.latitude, position.longitude));
    } catch (e) {
      if (!mounted) return;
      setState(() => data.generalError = 'Could not get your location: $e');
    }
  }

  void _pushSubmit(int height, DateTime date, String bio, String name) async {
    setState(() => data.currState = .saving);
    try {
      final uid = ref.read(currentUserIdProvider);
      await _requestLocation();
      await FirebaseFirestore.instance.collection('playerProfiles').doc(uid).update({
        'height': height,
        'position': playerPositionToInt(data.position),
        'bio': bio,
        'displayName': name,
      });
      await FirebaseFirestore.instance.collection('usernames').doc(name).set({});
      await FirebaseFirestore.instance.collection('users').doc(uid).update({'dateOfBirth': Timestamp.fromDate(date)});

      Future.wait([
        _pushImage(propertyName: 'photoUrl', uid: uid, image: data.profileImage),
        _pushImage(propertyName: 'bannerUrl', uid: uid, image: data.bannerImage),
      ]);
    } catch (e) {
      if (!mounted) return;
      setState(() => data.generalError = 'Could not save your profile. Please try again.');
      log(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          data.currState = .yes;
        });
      }
    }
  }

  Future<void> _pushImage({required String uid, required String propertyName, required XFile? image}) async {
    if (image == null) return;

    final file = File(image.path);
    final isBanner = propertyName == 'bannerUrl';

    final compressedFile = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      file.absolute.path.replaceAll('.jpg', '_compressed.jpg').replaceAll('.png', '_compressed.png'),
      quality: isBanner ? 85 : 60,
      minWidth: isBanner ? 1080 : 256,
      minHeight: isBanner ? 1080 : 256,
    );

    final uploadFile = compressedFile != null ? File(compressedFile.path) : file;

    final storageRef = FirebaseStorage.instance.ref().child('${propertyName}s').child('$uid.jpg');
    final uploadTask = await storageRef.putFile(uploadFile, SettableMetadata(contentType: 'image/jpeg'));
    final downloadUrl = await uploadTask.ref.getDownloadURL();

    await FirebaseFirestore.instance.collection('playerProfiles').doc(uid).update({propertyName: downloadUrl});
  }

  final PageController controller = .new();
  int _currPage = 0;
  final GlobalKey<FormState> formKey = .new();

  @override
  Widget build(BuildContext context) {
    final textTheme = TextTheme.of(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Center(child: Text("Set up your profile")),
        titleTextStyle: textTheme.titleLarge?.copyWith(fontWeight: .w600),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          BackgroundImage(),
          SizedBox.expand(
            child: GestureDetector(
              onTap: FocusScope.of(context).unfocus,
              behavior: HitTestBehavior.opaque,
              child: Column(
                children: [
                  Expanded(
                    child: PageView(
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (i) => setState(() => _currPage = i),
                      controller: controller,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 22, right: 22, top: 80, bottom: 22),
                          child: IgnorePointer(ignoring: !data.canEdit, child: _buildImagesForm()),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 22, right: 22, top: 80, bottom: 22),
                          child: _buildTextForms(context, ref),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 22, right: 22, bottom: 22),
                    child: Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: (() {
                              if (_currPage == 0) {
                                return () {
                                  FirebaseAuth.instance.signOut();
                                  GoogleSignIn.instance.signOut();
                                };
                              } else {
                                return () =>
                                    controller.previousPage(curve: Curves.easeInOut, duration: Durations.medium2);
                              }
                            })(),
                            child: Text(_currPage == 0 ? "Log Out" : "Previous"),
                          ),
                        ),
                        const SizedBox(width: 22),
                        Expanded(
                          child: DarkFilledButton(
                            onPressed: (() {
                              if (_currPage == 0) {
                                if (data.bannerImage == null || data.profileImage == null) return null;
                                return () => controller.nextPage(curve: Curves.easeInOut, duration: Durations.medium2);
                              }
                              final dat = formKey.currentState?.validate();
                              return dat == true ? _submit : null;
                            })(),
                            child: Text(_currPage == 0 ? "Continue" : "Finish"),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  int ageOn(DateTime date, DateTime now) {
    int age = now.year - date.year;
    if (now.month < date.month || (now.month == date.month && now.day < date.day)) {
      age--;
    }
    return age;
  }

  DateTime? tryDate(String? inp) {
    int daysInMonth(int year, int month) {
      return DateTime(year, month + 1, 0).day;
    }

    final split = inp?.split('/');
    if (split == null) return null;
    if (split.isEmpty) return null;
    if (split.length != 3) return null;
    int? day = int.tryParse(split[0]);
    if (day == null) return null;
    if (day < 1 || day > 31) return null;
    int? month = int.tryParse(split[1]);
    if (month == null) return null;
    if (month < 1 || month > 12) return null;
    int? year = int.tryParse(split[2]);
    if (year == null) return null;
    if (day > daysInMonth(year, month)) return null;
    final date = DateTime(year, month, day);
    return date;
  }

  Widget _buildTextForms(BuildContext context, WidgetRef ref) {
    final bool canEdit = data.canEdit;
    final name = (data.username?.length ?? -1) < 5 ? "New Player" : data.username!;
    final takenAsync = ref.watch(isNameTakenProvider(name));

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Form(
        autovalidateMode: .onUserInteraction,
        key: formKey,
        child: Column(
          mainAxisAlignment: .center,
          crossAxisAlignment: .stretch,
          children: [
            const SizedBox(height: 22),
            BlurredFormField(
              enabled: canEdit,
              inputFormatters: [DateInputFormatter()],
              message: "Enter your birthday (DD/MM/YYYY)",
              onChanged: (newValue) {
                final date = tryDate(newValue);
                data.birthday = date;
              },
              validator: (date) {
                if (date?.isEmpty ?? true) return " ";
                final datetime = tryDate(date);
                if (datetime == null) return "Please enter a valid date";
                if (ageOn(datetime, DateTime.now()) < 18) return "You must be at least 18 to use this app. ";
                return null;
              },
            ),
            const SizedBox(height: 22 - 4),
            PositionPicker(
              enabled: canEdit,
              selected: data.position,
              onSelectionChanged: (set) => setState(() => data.position = set),
            ),
            const SizedBox(height: 22 - 4),
            BlurredFormField(
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              enabled: canEdit,
              message: "Height (cm)",
              maxLength: 3,
              onChanged: (h) => data.height = int.tryParse(h),
              validator: (s) {
                final x = int.tryParse(s ?? "");
                if (x == null) return " ";
                if (x < 100 || x > 300) return "Please input a valid height";
                return null;
              },
            ),
            const SizedBox(height: 22),
            BlurredFormField(
              enabled: canEdit,
              message: "Username",
              maxLength: 12,
              onChanged: (s) {
                setState(() {
                  data.username = s;
                });
              },
              validator: (s) {
                if (s == null) return " ";
                if (s.length < 5) return "Username must be at least 5 characters";
                final value = takenAsync.isLoading ? false : takenAsync.value ?? false;
                if (!value) return null;
                return " ";
              },
            ),
            ...((data.username?.length ?? 0) >= 5
                ? [
                    const SizedBox(height: 6),
                    SkeletonWidget<bool>(
                      val: takenAsync,
                      dummyData: true,
                      builder: (bool taken) {
                        return Text("${data.username} is ${taken ? "already taken" : "available"}");
                      },
                    ),
                  ]
                : []),
            const SizedBox(height: 22),
            BlurredFormField(
              enabled: canEdit,
              message: "Bio...",
              onChanged: (s) {
                data.bio = s;
              },
            ),
            const SizedBox(height: 22),
            if (data.generalError != null)
              Text(data.generalError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ),
      ),
    );
  }

  void pickProfileImage() async {
    final picker = ImagePicker();
    final newImage = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 50,
    );
    if (newImage != null) {
      setState(() {
        data.profileImage = newImage;
      });
    }
  }

  void clearProfileImage() {
    setState(() => data.profileImage = null);
  }

  void pickBannerImage() async {
    final picker = ImagePicker();
    final newImage = await picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
    if (newImage != null) {
      setState(() {
        data.bannerImage = newImage;
      });
    }
  }

  void clearBannerImage() {
    setState(() => data.bannerImage = null);
  }

  Widget _buildImagesForm() {
    return Stack(
      children: [
        GestureDetector(
          onTap: data.bannerImage == null ? pickBannerImage : null,
          child: SizedBox.expand(
            child: BlurredContainer(
              elevation: 1, 
              sigma: 30,
              child: data.bannerImage == null
                  ? Icon(Icons.edit_rounded)
                  : Image(image: FileImage(File(data.bannerImage!.path)), fit: .cover),
            ),
          ),
        ),
        if (data.bannerImage != null) ...[
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Align(
              alignment: .topRight,
              child: Row(
                mainAxisSize: .min,
                children: [
                  IconButton(icon: Icon(Icons.edit_rounded), onPressed: pickBannerImage),
                  const SizedBox(width: 8),
                  IconButton(icon: Icon(Icons.delete_rounded), onPressed: clearBannerImage),
                ],
              ),
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.all(10.0),
          child: GestureDetector(
            onTap: pickProfileImage,
            child: SizedBox(
              height: 150,
              width: 150,
              child: BlurredContainer(
                elevation: 3, 
                radius: 26,
                sigma: 30,
                child: data.profileImage == null
                    ? Icon(Icons.edit_rounded)
                    : Image(image: FileImage(File(data.profileImage!.path)), fit: .cover),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class FormData {
  SubmitState currState = SubmitState.yes; // State only in terms of saving or verifying, no validation

  bool get canEdit => !(currState == .saving || currState == .verifying);

  XFile? profileImage;
  XFile? bannerImage;
  String? username;
  String? bio;
  int? height;
  PlayerPosition position = .guard;
  DateTime? birthday;

  String? generalError;
}
