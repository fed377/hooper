import 'dart:developer' show log;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../data/providers.dart';
import '../models/matchup.dart' show tierForElo, tierLabel;
import '../models/player_profile.dart';

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
      // Standard geolocator permission dance: check first, request if
      // denied, bail out cleanly on either flavor of "no."
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Turn on location services and try again.')));
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
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: Icon(Icons.exit_to_app_rounded),
            onPressed: () {
              FirebaseAuth.instance.signOut();
            },
          ),
          if (!_editing && profileAsync.hasValue)
            IconButton(icon: const Icon(Icons.edit), onPressed: () => _enterEditMode(profileAsync.value!)),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, t) {
          log(t.toString());
          return Center(child: Text('Could not load your profile: $err'));
        },
        data: (profile) => _editing ? _buildEditForm(uid, profile.displayName) : _buildViewMode(profile),
      ),
    );
  }

  Widget _buildViewMode(PlayerProfile profile) {
    final tier = tierForElo(profile.elo);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        CircleAvatar(
          radius: 40,
          backgroundImage: profile.photoUrl != null ? NetworkImage(profile.photoUrl!) : null,
          child: profile.photoUrl != null ? Text(profile.displayName.substring(0, 1)) : null,
        ),
        const SizedBox(height: 12),
        Text(profile.displayName, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(tierLabel(tier), style: Theme.of(context).textTheme.bodyMedium),
        if (profile.locked) ...[
          const SizedBox(height: 8),
          const Chip(label: Text('Currently locked in an active match')),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            _StatBox(label: '1v1 elo', value: '${profile.elo}'),
            const SizedBox(width: 12),
            _StatBox(label: 'Games played', value: '${profile.gamesPlayed1v1}'),
          ],
        ),
        const SizedBox(height: 20),
        if (profile.bio.isNotEmpty) ...[
          Text('Bio', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(profile.bio),
          const SizedBox(height: 16),
        ],
        Text(['${profile.height} cm', profile.position].join(' · ')),
        const SizedBox(height: 8),
        Text(
          'Visible to players within ${profile.visibilityRadius.toStringAsFixed(0)} km',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _updatingLocation ? null : () => _updateLocation(profile.userId),
          icon: _updatingLocation
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.my_location),
          label: Text(profile.homeLocation == null ? "Set my location so I show up nearby" : 'Update my location'),
        ),
      ],
    );
  }

  Widget _buildEditForm(String uid, String oldName) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Display name', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _bioController,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Bio', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _heightController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Height (cm)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<PlayerPosition>(
          value: _position,
          decoration: const InputDecoration(labelText: 'Position', border: OutlineInputBorder()),
          items: PlayerPosition.values.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
          onChanged: (p) => setState(() => _position = p),
        ),
        const SizedBox(height: 12),
        Text('Discovery radius: ${_visibilityRadiusKm.toStringAsFixed(0)} km'),
        Slider(
          value: _visibilityRadiusKm.toDouble(),
          min: 1,
          max: 50,
          divisions: 49,
          label: '${_visibilityRadiusKm.toStringAsFixed(0)} km',
          onChanged: (v) => setState(() => _visibilityRadiusKm = v.toInt()),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
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
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  const _StatBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
