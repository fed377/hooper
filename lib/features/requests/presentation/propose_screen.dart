import 'dart:developer' show log;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hooper/features/discovery/data/matchups_repo.dart';
import 'package:hooper/features/matches/data/match_doc.dart';
import 'package:hooper/features/chat/presentation/chat_screen.dart';
import 'package:hooper/features/location/presentation/location_picker.dart';

import '../../../core/services/providers.dart';
import '../../discovery/data/matchup.dart';
import '../../../core/widgets/skeleton_widget.dart';

class ProposeMatchScreen extends ConsumerStatefulWidget {
  final String targetId;
  const ProposeMatchScreen({super.key, required this.targetId});

  static void pushProposal(String targetId, BuildContext context) {
    showModalBottomSheet(
      showDragHandle: true,
      context: context,
      builder: (context) {
        return ProposeMatchScreen(targetId: targetId);
      },
    );
  }

  @override
  ConsumerState<ProposeMatchScreen> createState() => _ProposeMatchScreenState();
}

class _ProposeMatchScreenState extends ConsumerState<ProposeMatchScreen> {
  final _courtController = TextEditingController();
  DateTime? _selectedTime;
  bool _sending = false;
  LocationPickerController locationController = LocationPickerController(point: GeoPoint(0, 0));
  bool _private = false;
  bool _friendly = false;

  Future<void> _pickTime() async {
    final date = await showDatePicker(
      context: context,
      firstDate: .now(),
      lastDate: .now().add(const Duration(days: 14)),
      initialDate: .now().add(Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null) return;
    setState(() {
      _selectedTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _send() async {
    final court = _courtController.text.trim();
    if (court.isEmpty || _selectedTime == null) return;
    if (!locationController.hasMoved) return;
    setState(() => _sending = true);
    try {
      final repo = ref.read(matchupRepositoryProvider);
      final response = await repo.proposeMatch(
        targetId: widget.targetId,
        court: court,
        scheduledTime: _selectedTime!,
        location: GeoPoint(locationController.point.latitude, locationController.point.longitude),
        friendly: _friendly, 
        private: _private,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ChatScreen(chatId: response.chatId)));
    } on ProposalException catch (e) {
      if (!mounted) return;
      log(e.toString());
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final matchupAsync = ref.watch(matchupFromIdProvider(widget.targetId));
    return SkeletonWidget<Matchup>(
      val: matchupAsync,
      dummyData: Matchup.dummy(),
      builder: (data) => _buildBody(context, data),
    );
  }

  Widget _buildBody(BuildContext context, Matchup target) {
    final lockedMatchesAsync = ref.watch(lockedMatchesProvider);
    final locationAsync = ref.read(myLocationProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Challenge ${target.displayName}', style: Theme.of(context).textTheme.titleLarge),
        Text('Where do you want to play?', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _courtController,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Court',
            hintText: 'e.g. Riverside Courts, west hoop',
            border: OutlineInputBorder(),
          ),
        ),
        SkeletonWidget<Position>(
          builder: (pos) {
            locationController.point = GeoPoint(pos.latitude, pos.longitude);
            return LocationPicker(controller: locationController);
          },
          val: locationAsync,
          dummyData: Position(
            longitude: 0,
            latitude: 0,
            timestamp: .now(),
            accuracy: 0,
            altitude: 0,
            altitudeAccuracy: 0,
            heading: 0,
            headingAccuracy: 0,
            speed: 0,
            speedAccuracy: 0,
          ),
        ),
        
        const SizedBox(height: 24),
        Text('When?', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _pickTime,
          child: Text(_selectedTime == null ? 'Pick date & time' : _selectedTime.toString()),
        ),
        const SizedBox(height: 24),
        SkeletonWidget<List<MatchDoc>?>(
          val: lockedMatchesAsync,
          dummyData: [],
          builder: (data) {
            log(data?.length.toString() ?? "null");
            bool pass = checkPass(data);
            log(pass.toString());
            return FilledButton(
              onPressed: (_courtController.text.trim().isNotEmpty && !_sending && pass) ? _send : null,
              child: const Text('Send challenge'),
            );
          },
        ),
      ],
    );
  }

  bool? _checkConflict(List<MatchDoc>? data, DateTime requestStart, DateTime requestEnd) {
    return data?.every((doc) {
      final startTime = doc.scheduledTime;
      final endTime = startTime.add(Duration(hours: 1));
      final canPass =
          (startTime.isBefore(requestStart) && endTime.isBefore(requestStart)) ||
          (endTime.isAfter(requestEnd) && startTime.isAfter(requestEnd));
      return canPass;
    });
  }

  bool checkPass(List<MatchDoc>? data) {
    final rs = _selectedTime;
    if (rs == null) return false;
    final re = rs.add(Duration(hours: 1));
    bool pass = _checkConflict(data, rs, re) ?? true;
    return pass;
  }
}
