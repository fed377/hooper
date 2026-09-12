import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hooper/core/utils/utils.dart';
import 'package:hooper/core/widgets/blurred_container.dart';
import 'package:hooper/core/widgets/blurred_text_field.dart';
import 'package:hooper/core/widgets/custom_data_box.dart';
import 'package:hooper/core/widgets/dark_buttons.dart';
import 'package:hooper/core/widgets/skeleton_widget.dart';
import 'package:hooper/features/matches/presentation/matches_list.dart';
import 'package:hooper/features/profile/presentation/user_settings_screen.dart';

import '../../../core/services/providers.dart';
import '../../../core/widgets/animated_blurred_picker.dart';
import '../../../core/widgets/position_picker.dart';
import '../../discovery/data/matchup.dart' show tierForElo, tierLabel;
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

  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _heightController = TextEditingController();
  PlayerPosition? _position;
  int _visibilityRadiusKm = 10;

  void _enterEditMode(PlayerProfile profile) {
    _nameController.text = profile.displayName;
    _bioController.text = profile.bio;
    _heightController.text = profile.height.toString();
    _position = playerPositionFromInt(profile.position);
    _visibilityRadiusKm = profile.visibilityRadius;
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

  Future<void> _save(String uid, String oldName) async {
    setState(() => _saving = true);
    final repo = ref.read(playerProfileRepositoryProvider);
    try {
      await repo.updateEditableFields(
        uid: uid,
        oldName: oldName,
        bio: _bioController.text.trim(),
        heightCm: int.tryParse(_heightController.text.trim()),
        position: _position,
        visibilityRadiusKm: _visibilityRadiusKm,
        displayName: _nameController.text,
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
              if (profile.bannerUrl != null && profile.bannerUrl != '')
                SizedBox.expand(
                  child: ClipRect(
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10, tileMode: .mirror),
                      child: Image(fit: .cover, image: ref.read(imageProviderFamily(profile.bannerUrl!))),
                    ),
                  ),
                ),
              SizedBox.expand(
                child: ListView(
                  children: [
                    AppBar(
                      backgroundColor: Colors.transparent,
                      actions: [
                        if (!_editing && profileAsync.hasValue)
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _enterEditMode(profileAsync.value!),
                          ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.settings),
                          onPressed: () =>
                              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UserSettingsScreen())),
                        ),
                        const SizedBox(width: 16),
                      ],
                    ),
                    _editing ? _buildEditForm(uid, profile.displayName) : _buildViewMode(profile),
                  ],
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
    final tier = tierForElo(profile.elo);
    final rankAsync = ref.watch(rankProvider(profile.userId));
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16),
      child: Column(
        children: [
          rankAsync.maybeWhen(orElse: () => const SizedBox()),
          const SizedBox(height: 12),
          SizedBox(
            child: Row(
              crossAxisAlignment: .start,
              children: [
                SizedBox(
                  child: CircleAvatar(
                    radius: 70,
                    backgroundImage: profile.photoUrl != null ? CachedNetworkImageProvider(profile.photoUrl!) : null,
                    child: profile.photoUrl == null ? Text(profile.displayName.substring(0, 1)) : null,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  mainAxisSize: .min,
                  crossAxisAlignment: .start,
                  children: [
                    Row(
                      crossAxisAlignment: .baseline,
                      textBaseline: .alphabetic,
                      children: [
                        Text(
                          '${profile.displayName} ⋅ ',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: .w900),
                        ),
                        Text(tierLabel(tier), style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                    SizedBox(
                      width: MediaQuery.sizeOf(context).width - 150 - 16 * 2,
                      child: Text(profile.bio.isEmpty ? "No bio yet. " : profile.bio),
                    ),
                  ],
                ),
              ],
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
                child: CustomDataBox(label: 'ELO', value: '${profile.elo}', icon: Icons.leaderboard_rounded),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: CustomDataBox(label: 'Games', value: '${profile.gamesPlayed1v1}', icon: Icons.games_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: CustomDataBox(label: 'Height', value: '${profile.height}', icon: Icons.height_rounded),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: CustomDataBox(
                  label: 'Position',
                  value: capitalize(playerPositionFromInt(profile.position)?.name),
                  icon: Icons.person_2_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          BlurredContainer(
            elevation: 2, 
            sigma: 0,
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
    final colors = HooprColors.instance;
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        setState(() => _editing = false);
      },
      canPop: false,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            BlurredTextField(controller: _nameController, message: 'Display Name'),
            const SizedBox(height: 12),
            BlurredTextField(controller: _bioController, message: 'Bio', maxLines: 3, maxLength: 100),
            const SizedBox(height: 12),
            BlurredTextField(controller: _heightController, keyboardType: TextInputType.number, message: 'Height (cm)'),
            const SizedBox(height: 12),
            PositionPicker(
              enabled: true,
              selected: _position ?? PlayerPosition.guard,
              onSelectionChanged: (set) => setState(() => _position = set),
            ),
            const SizedBox(height: 12),
            BlurredContainer(
              elevation: 1, 
              color: colors.blurColor,
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
                    value: _visibilityRadiusKm.toDouble(),
                    min: 1,
                    max: 50,
                    divisions: 49,
                    onChanged: (v) => setState(() => _visibilityRadiusKm = v.toInt()),
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
    );
  }
}
