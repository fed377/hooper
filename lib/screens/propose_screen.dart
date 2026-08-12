import 'dart:developer' show log;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooper/screens/chat_screen.dart';

import '../../data/providers.dart';
import '../../data/repos/matchup_repo.dart';
import '../../models/matchup.dart';

class ProposeMatchScreen extends ConsumerStatefulWidget {
  final Matchup target;
  const ProposeMatchScreen({super.key, required this.target});

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
      final response = await repo.proposeMatch(targetId: widget.target.id, court: court, scheduledTime: _selectedTime!);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ChatScreen(chatId: response.chatId, onPropose: null)));
    } on ProposeMatchException catch (e) {
      if (!mounted) return;
      // failed-precondition here specifically means "they got locked
      // by someone else between when the feed loaded and now" — worth
      // a distinct message rather than a generic error.
      log(e.toString());
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Challenge ${widget.target.displayName}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Where do you want to play?', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _courtController,
            onChanged: (_) => setState(() {}), // keep Send button's enabled state live
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
          const SizedBox(height: 8),
          Text(
            "Both of these are just a starting point — you'll be able to "
            "discuss and change them with ${widget.target.displayName} in chat "
            "before they accept.",
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: (_courtController.text.trim().isNotEmpty && _selectedTime != null && !_sending) ? _send : null,
            child: _sending
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Send challenge'),
          ),
        ],
      ),
    );
  }
}
