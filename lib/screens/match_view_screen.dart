import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooper/models/chat.dart';
import 'package:hooper/screens/chat_screen.dart';

import '../data/providers.dart';
import '../data/repos/match_repo.dart';
import '../models/match_doc.dart';

class MatchViewScreen extends ConsumerWidget {
  final String matchId;
  const MatchViewScreen({super.key, required this.matchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUserIdProvider);
    final matchAsync = ref.watch(matchProvider(matchId));

    return Scaffold(
      appBar: AppBar(title: const Text('Match')),
      body: matchAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(padding: const EdgeInsets.all(24), child: Text('Could not load this match: $err')),
        ),
        data: (match) => _MatchBody(match: match, uid: uid),
      ),
    );
  }
}

class _MatchBody extends ConsumerWidget {
  final MatchDoc match;
  final String uid;
  const _MatchBody({required this.match, required this.uid});

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this match?'),
        content: const Text("This can't be undone — you'll both need to reschedule."),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Back')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Cancel match')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(matchRepositoryProvider).cancelMatch(match.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Match cancelled.')));
      }
    } on MatchActionException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final otherId = match.otherParticipant(uid);
    final nameAsync = ref.watch(playerDisplayNameProvider(otherId));
    final canCancel = match.status == MatchStatus.scheduled || match.status == MatchStatus.inProgress;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: Column(
            children: [
              CircleAvatar(radius: 32, child: Text(nameAsync.value?.substring(0, 1) ?? '?')),
              const SizedBox(height: 10),
              Text(nameAsync.value ?? 'Loading…', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              _StatusChip(status: match.status),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _InfoRow(icon: Icons.place_outlined, label: 'Court', value: match.court),
        _InfoRow(icon: Icons.schedule_outlined, label: 'Time', value: match.scheduledTime.toString()),
        const SizedBox(height: 20),

        if (match.status == MatchStatus.confirmed) _buildResult(context),
        if (match.status == MatchStatus.cancelled) const Text('This match was cancelled.', textAlign: TextAlign.center),
        if (match.status == MatchStatus.scheduled)
          const Text(
            "This match hasn't started yet — you'll be prompted to enter a score once it does.",
            textAlign: TextAlign.center,
          ),
        if (match.status == MatchStatus.inProgress ||
            match.status == MatchStatus.awaitingConfirmation ||
            match.status == MatchStatus.disputed)
          const Text("This match is currently underway.", textAlign: TextAlign.center),

        const SizedBox(height: 28),
        OutlinedButton.icon(
          icon: const Icon(Icons.chat_bubble_outline),
          label: const Text('Open chat'),
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => ChatScreen(chatId: Chat.pairChatId(match.sideAId, match.sideBId)))),
        ),
        if (canCancel) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _confirmCancel(context, ref),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Cancel match'),
          ),
        ],
      ],
    );
  }

  Widget _buildResult(BuildContext context) {
    final delta = match.myEloDelta(uid);
    final won = delta != null && delta > 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            won ? 'Victory' : 'Defeat',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: won ? Colors.green : Colors.red, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text('${match.scoreA} – ${match.scoreB}', style: Theme.of(context).textTheme.headlineMedium),
          if (delta != null) ...[
            const SizedBox(height: 8),
            Text(
              '${delta > 0 ? '+' : ''}$delta elo',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: delta > 0 ? Colors.green : Colors.red),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.outline),
                ),
                Text(value, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final MatchStatus status;
  const _StatusChip({required this.status});

  (String, Color?) _labelAndColor(BuildContext context) {
    switch (status) {
      case MatchStatus.scheduled:
        return ('Upcoming', null);
      case MatchStatus.inProgress:
        return ('In progress', Colors.orange);
      case MatchStatus.awaitingConfirmation:
        return ('Awaiting confirmation', Colors.orange);
      case MatchStatus.disputed:
        return ('Disputed', Theme.of(context).colorScheme.error);
      case MatchStatus.confirmed:
        return ('Confirmed', Colors.green);
      case MatchStatus.cancelled:
        return ('Cancelled', null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (label, color) = _labelAndColor(context);
    return Chip(
      label: Text(label),
      labelStyle: color != null ? TextStyle(color: color) : null,
      visualDensity: VisualDensity.compact,
    );
  }
}
