import 'dart:developer' show log;
import 'dart:io';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hooper/core/utils/utils.dart';
import 'package:hooper/core/widgets/blurred_container.dart';
import 'package:hooper/core/widgets/blurred_text_field.dart';
import 'package:hooper/core/widgets/custom_data_box.dart';
import 'package:hooper/core/widgets/dark_buttons.dart';
import 'package:hooper/core/widgets/elo_history_chart.dart';
import 'package:hooper/core/widgets/skeleton_widget.dart';
import 'package:hooper/features/matches/presentation/matches_list.dart';
import 'package:hooper/features/profile/presentation/user_settings_screen.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/providers.dart';
import '../../../core/widgets/animated_blurred_picker.dart';
import '../../../core/widgets/elo_rank_chip.dart';
import '../../../core/widgets/position_picker.dart';
import '../../profile/data/player_profile.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _editing = false;
  bool _saving = false;
  bool _updatingLocation = false;
  bool _uploadingPhoto = false;
  bool _uploadingBanner = false;

  final _editFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _heightController = TextEditingController();
  PlayerPosition? _position;
  double _visibilityRadiusKm = 10;

  void _enterEditMode(PlayerProfile profile) {
    _nameController.text = profile.displayName;
    _bioController.text = profile.bio;
    _heightController.text = profile.height.toString();
    _position = playerPositionFromInt(profile.position);
    _visibilityRadiusKm = profile.visibilityRadius.toDouble();
    setState(() => _editing = true);
  }

  Future<void> _updateLocation(String uid) async {
    setState(() => _updatingLocation = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Location permission is needed to show up in nearby matchups.')));
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Turn on location services and try again.')));
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      await ref
          .read(playerProfileRepositoryProvider)
          .updateLocation(uid, GeoPoint(position.latitude, position.longitude));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location updated.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update location: $e')));
    } finally {
      if (mounted) setState(() => _updatingLocation = false);
    }
  }

  Future<void> _changeImage(String uid, {required bool isBanner}) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: isBanner ? null : 512,
      maxHeight: isBanner ? null : 512,
      imageQuality: isBanner ? 100 : 50,
    );
    if (image == null) return;

    setState(() => isBanner ? _uploadingBanner = true : _uploadingPhoto = true);
    try {
      await _uploadImage(uid: uid, propertyName: isBanner ? 'bannerUrl' : 'photoUrl', image: image);
    } catch (e, trace) {
      log(trace.toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not update ${isBanner ? 'banner' : 'photo'}: $e')));
    } finally {
      if (mounted) setState(() => isBanner ? _uploadingBanner = false : _uploadingPhoto = false);
    }
  }

  Future<void> _uploadImage({required String uid, required String propertyName, required XFile image}) async {
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

  Future<void> _save(String uid, String oldName) async {
    if (_editFormKey.currentState?.validate() != true) return;

    final newName = _nameController.text.trim();
    setState(() => _saving = true);
    final repo = ref.read(playerProfileRepositoryProvider);
    try {
      if (newName != oldName) {
        final taken = await ref.read(isNameTakenProvider(newName).future);
        if (taken) {
          if (!mounted) return;
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('That display name is already taken.')));
          return;
        }
      }
      await repo.updateEditableFields(
        uid: uid,
        oldName: oldName,
        bio: _bioController.text.trim(),
        heightCm: int.tryParse(_heightController.text.trim()),
        position: _position,
        visibilityRadiusKm: _visibilityRadiusKm.toInt(),
        displayName: newName,
      );
      if (!mounted) return;
      setState(() => _editing = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save changes: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUserIdProvider);
    final profileAsync = ref.watch(myPlayerProfileProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: SkeletonWidget<PlayerProfile>(
        val: profileAsync,
        dummyData: PlayerProfile.dummy(),
        builder: (profile) {
          if (profile.userId == '') {
            return _buildViewMode(profile);
          }
          return Stack(
            children: [
              if (profile.bannerUrl != null && profile.bannerUrl != '' && HooprTheme.instance.glass)
                SizedBox.expand(
                  child: ClipRect(
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10, tileMode: .mirror),
                      child: Image(fit: .cover, image: ref.read(imageProviderFamily(profile.bannerUrl!))),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(bottom: 88),
                child: SizedBox.expand(
                  child: ListView(
                    children: [
                      AppBar(
                        backgroundColor: Colors.transparent,
                        actions: [
                          if (!_editing && profileAsync.hasValue) ...[
                            IconButton(
                              icon: _uploadingBanner
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.image_outlined),
                              tooltip: 'Change banner',
                              onPressed: _uploadingBanner
                                  ? null
                                  : () => _changeImage(profileAsync.value!.userId, isBanner: true),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _enterEditMode(profileAsync.value!),
                            ),
                          ],
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(Icons.settings),
                            onPressed: () =>
                                Navigator.of(context)
                                    .push(MaterialPageRoute(builder: (_) => const UserSettingsScreen())),
                          ),
                          const SizedBox(width: 16),
                        ],
                      ),
                      _editing ? _buildEditForm(uid, profile.displayName) : _buildViewMode(profile),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  int currItem = 0;

  Widget _buildViewMode(PlayerProfile profile) {
    final hasBanner = profile.bannerUrl != null && profile.bannerUrl != '' && HooprTheme.instance.glass;
    final surfaceColor = hasBanner ? const Color.fromARGB(110, 255, 255, 255) : null;
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16),
      child: Column(
        children: [
          const SizedBox(height: 12),
          BlurredContainer(
            elevation: 1,
            radius: 28,
            color: surfaceColor,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: .center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: profile.photoUrl != null
                            ? ResizeImage(CachedNetworkImageProvider(profile.photoUrl!), width: 300)
                            : null,
                        child: profile.photoUrl == null ? Text(profile.displayName.substring(0, 1)) : null,
                      ),
                      if (profile.userId != '')
                        Positioned(
                          bottom: -4,
                          right: -4,
                          child: GestureDetector(
                            onTap: _uploadingPhoto ? null : () => _changeImage(profile.userId, isBanner: false),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                              child: _uploadingPhoto
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: .min,
                      crossAxisAlignment: .start,
                      children: [
                        Text(
                          profile.displayName,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: .w900),
                        ),
                        const SizedBox(height: 6),
                        EloRankChip(elo: profile.elo),
                        const SizedBox(height: 8),
                        Text(profile.bio.isEmpty ? "No bio yet. " : profile.bio),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          DarkFilledButton(
            onPressed: _updatingLocation ? null : () => _updateLocation(profile.userId),
            child: Row(
              mainAxisSize: .max,
              mainAxisAlignment: .center,
              children: [
                _updatingLocation
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.my_location),
                const SizedBox(width: 8),
                Text(profile.homeLocation == null ? "Set my location so I show up nearby" : 'Update my location'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: CustomDataBox(
                  label: 'ELO',
                  value: '${profile.elo}',
                  icon: Icons.leaderboard_rounded,
                  color: surfaceColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: CustomDataBox(
                  label: 'Games',
                  value: '${profile.gamesPlayed1v1}',
                  icon: Icons.games_rounded,
                  color: surfaceColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: CustomDataBox(
                  label: 'Height',
                  value: '${profile.height}',
                  icon: Icons.height_rounded,
                  color: surfaceColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: CustomDataBox(
                  label: 'Position',
                  value: capitalize(playerPositionFromInt(profile.position)?.name),
                  icon: Icons.person_2_rounded,
                  color: surfaceColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          EloHistoryChart(uid: profile.userId, fallbackElo: profile.elo, chartHeight: 110),
          const SizedBox(height: 20),
          BlurredContainer(
            elevation: 1,
            sigma: 0,
            color: surfaceColor,
            child: Column(
              mainAxisSize: .min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6.0, left: 6, right: 6),
                  child: AnimatedBlurredPicker(
                    includeBlurredContainer: false,
                    stretchFactor: 0.5,
                    duration: Durations.medium1,
                    radius: 36,
                    height: 55,
                    currItem: currItem.toDouble(),
                    elements: [
                      Row(
                        mainAxisSize: .min,
                        children: [
                          const SizedBox(width: 8),
                          Text("Finished"),
                          const SizedBox(width: 8),
                          Icon(Icons.history_rounded),
                          const SizedBox(width: 8),
                        ],
                      ),
                      Row(
                        mainAxisSize: .min,
                        children: [
                          const SizedBox(width: 8),
                          Text("Upcoming"),
                          const SizedBox(width: 8),
                          Icon(Icons.schedule_rounded),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ],
                    onTap: (int p1) {
                      setState(() => currItem = p1);
                    },
                  ),
                ),
                MatchesList(
                  includeBlurredContainer: false,
                  label: currItem == 1 ? "Upcoming Matches" : "Finished Matches",
                  matchesAsync: AsyncValue.data(
                    (currItem == 1 ? profile.lockedMatchIds : profile.completedMatchIds) ?? [],
                  ),
                  userId: profile.userId,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditForm(String uid, String oldName) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        setState(() => _editing = false);
      },
      canPop: false,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _editFormKey,
          autovalidateMode: .onUserInteraction,
          child: Column(
            children: [
              BlurredFormField(
                controller: _nameController,
                message: 'Display Name',
                maxLength: 12,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]'))],
                validator: (s) {
                  final value = (s ?? '').trim();
                  if (value.isEmpty) return ' ';
                  if (value.length < 5) return 'Must be at least 5 characters';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              BlurredFormField(controller: _bioController, message: 'Bio', maxLength: 100, maxLines: 3),
              const SizedBox(height: 12),
              BlurredFormField(
                controller: _heightController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 3,
                message: 'Height (cm)',
                validator: (s) {
                  final x = int.tryParse(s ?? '');
                  if (x == null) return ' ';
                  if (x < 100 || x > 300) return 'Please enter a valid height';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              PositionPicker(
                enabled: true,
                selected: _position ?? PlayerPosition.guard,
                onSelectionChanged: (set) => setState(() => _position = set),
              ),
              const SizedBox(height: 12),
              BlurredContainer(
                elevation: 1,
                borderWidth: 1.5,
                radius: 22,
                child: Column(
                  mainAxisSize: .min,
                  crossAxisAlignment: .start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 20.0, top: 18),
                      child: Text('Discovery radius: ${_visibilityRadiusKm.toStringAsFixed(0)} km'),
                    ),
                    Slider(
                      value: _visibilityRadiusKm,
                      min: 1,
                      max: 50,
                      activeColor: Colors.black,
                      inactiveColor: HooprTheme.instance.darkenColor,
                      onChanged: (v) => setState(() => _visibilityRadiusKm = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: DarkFilledButton(
                      onPressed: _saving ? null : () => setState(() => _editing = false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : () => _save(uid, oldName),
                      child: _saving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
