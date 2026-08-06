import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repos/matchup_repo.dart';
import '../../models/court.dart';
import '../../models/matchup.dart';

class ProposeMatchScreen extends ConsumerStatefulWidget {
  final Matchup target;
  const ProposeMatchScreen({super.key, required this.target});

  @override
  ConsumerState<ProposeMatchScreen> createState() => _ProposeMatchScreenState();
}

class _ProposeMatchScreenState extends ConsumerState<ProposeMatchScreen> {
  Court? _selectedCourt;
  DateTime? _selectedTime;
  bool _sending = false;

  Future<void> _pickTime() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 14)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null) return;
    setState(() {
      _selectedTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _send() async {
    if (_selectedCourt == null || _selectedTime == null) return;
    setState(() => _sending = true);
    try {
      final repo = ref.read(matchupRepositoryProvider);
      await repo.proposeMatch(targetId: widget.target.id, courtId: _selectedCourt!.id, scheduledTime: _selectedTime!);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Challenge sent to ${widget.target.displayName}')));
      Navigator.of(context).pop();
    } on ProposeMatchException catch (e) {
      if (!mounted) return;
      // failed-precondition here specifically means "they got locked
      // by someone else between when the feed loaded and now" — worth
      // a distinct message rather than a generic error.
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Choose a time', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _pickTime,
          child: Text(_selectedTime == null ? 'Pick date & time' : _selectedTime.toString()),
        ),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: (_selectedCourt != null && _selectedTime != null && !_sending) ? _send : null,
          child: _sending
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Send challenge'),
        ),
      ],
    );
  }
}
