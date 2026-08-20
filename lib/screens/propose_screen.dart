import 'dart:developer' show log;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooper/models/match_doc.dart';
import 'package:hooper/screens/chat_screen.dart';

import '../../data/providers.dart';
import '../../data/repos/matchup_repo.dart';
import '../../models/matchup.dart';

class ProposeMatchScreen extends ConsumerStatefulWidget {
  final String targetId;
  const ProposeMatchScreen({super.key, required this.targetId});

  static void pushProposal(final String targetId, BuildContext context) {
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

  Future<void> _pickTime() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 14)),
      initialDate: DateTime.now().add(Duration(days: 1)),
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
    setState(() => _sending = true);
    try {
      final repo = ref.read(matchupRepositoryProvider);
      final response = await repo.proposeMatch(targetId: widget.targetId, court: court, scheduledTime: _selectedTime!);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ChatScreen(chatId: response.chatId)));
    } on ProposeMatchException catch (e) {
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
    return matchupAsync.when(
      data: (Matchup data) {
        return _buildBody(context, data);
      },
      error: (Object error, StackTrace stackTrace) {
        return Center(child: Text(error.toString()));
      },
      loading: () {
        return Center(child: const CircularProgressIndicator());
      },
    );
  }

  Widget _buildBody(BuildContext context, Matchup target) {
    final lockedMatchesAsync = ref.watch(lockedMatchesProvider);
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
        const SizedBox(height: 24),
        Text('When?', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _pickTime,
          child: Text(_selectedTime == null ? 'Pick date & time' : _selectedTime.toString()),
        ),
        const SizedBox(height: 24),
        lockedMatchesAsync.when(
          data: (data) {
            log(data?.length.toString() ?? "null");
            bool pass = checkPass(data);
            log(pass.toString());
            return FilledButton(
              onPressed: (_courtController.text.trim().isNotEmpty && !_sending && pass) ? _send : null,
              child: _sending
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Send challenge'),
            );
          },
          error: (Object error, StackTrace stackTrace) {
            return Text(error.toString());
          },
          loading: () {
            return const SizedBox(width: 16, height: 16, child: CircularProgressIndicator());
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
