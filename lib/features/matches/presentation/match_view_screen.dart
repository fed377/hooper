import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooper/core/widgets/skeleton_widget.dart';
import 'package:hooper/features/matches/data/match_repo.dart';
import 'package:hooper/features/chat/data/chat.dart';
import 'package:hooper/features/discovery/data/matchup.dart';
import 'package:hooper/features/chat/presentation/chat_screen.dart';
import 'package:hooper/features/requests/presentation/matchup_view_screen.dart';

import '../../../core/services/providers.dart';
import '../data/match_doc.dart';

//View a match that is not currently ongoing
class MatchViewScreen extends ConsumerWidget {
  final String matchId;
  const MatchViewScreen({super.key, required this.matchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUserIdProvider);
    final matchAsync = ref.watch(matchProvider(matchId));

    return Scaffold(
      appBar: AppBar(title: const Text('Match')),
      body: SkeletonWidget<MatchDoc>(
        val: matchAsync,
        builder: (match) => _MatchBody(match: match, uid: uid),
        dummyData: MatchDoc.dummy(),
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

  Widget _buildDisplayCard(BuildContext context, Matchup m) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MatchupViewScreen(matchup: m))),
      child: Column(
        children: [
          CircleAvatar(
            radius: 46,
            foregroundImage: (m.photoUrl != null) ? CachedNetworkImageProvider(m.photoUrl!) : null,
            child: (m.photoUrl == null) ? Text(m.displayName[0]) : null,
          ),
          const SizedBox(height: 10),
          Text(m.displayName, style: Theme.of(context).textTheme.headlineSmall),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mySide = match.mySide(uid);
    final isParticipant = mySide != null;

    final meAsync = ref.watch(matchupFromIdProvider(mySide == 'B' ? match.sideBId : match.sideAId));
    final otherAsync = ref.watch(matchupFromIdProvider(mySide == 'B' ? match.sideAId : match.sideBId));

    final nameAAsync = ref.watch(playerDisplayNameProvider(match.sideAId));
    final nameBAsync = ref.watch(playerDisplayNameProvider(match.sideBId));

    final canCancel =
        isParticipant && (match.status == MatchStatus.scheduled || match.status == MatchStatus.inProgress);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (!isParticipant)
          Center(
            child: Row(
              mainAxisSize: .min,
              children: [
                if (!isParticipant) ...[
                  SkeletonWidget<Matchup>(
                    val: meAsync,
                    dummyData: Matchup.dummy(),
                    builder: (Matchup m) => _buildDisplayCard(context, m),
                  ),
                  Column(
                    mainAxisAlignment: .end,
                    children: [
                      const SizedBox(height: 102, width: 50),
                      Text(" vs ", style: Theme.of(context).textTheme.headlineSmall),
                    ],
                  ),
                ],
                SkeletonWidget<Matchup>(
                  val: otherAsync,
                  dummyData: Matchup.dummy(),
                  builder: (Matchup m) => _buildDisplayCard(context, m),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        _StatusChip(status: match.status),
        const SizedBox(height: 24),
        _InfoRow(icon: Icons.place_outlined, label: 'Court', value: match.court),
        _InfoRow(icon: Icons.schedule_outlined, label: 'Time', value: match.scheduledTime.toString()),
        const SizedBox(height: 20),
        if (match.status == MatchStatus.confirmed) _buildResult(context, mySide, nameAAsync.value, nameBAsync.value),
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
        if (isParticipant)
          OutlinedButton.icon(
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Open chat'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ChatScreen(chatId: Chat.pairChatId(match.sideAId, match.sideBId))),
            ),
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

  Widget _buildResult(BuildContext context, String? mySide, String? nameA, String? nameB) {
    final aWon = (match.scoreA ?? 0) > (match.scoreB ?? 0);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: ShapeDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        shape: RoundedSuperellipseBorder(borderRadius: .circular(22)),
      ),
      child: Column(
        children: [
          Text('${match.scoreA} – ${match.scoreB}', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          _ResultSideRow(name: nameA ?? '…', isMe: mySide == 'A', won: aWon, delta: match.eloDeltaA),
          const SizedBox(height: 6),
          _ResultSideRow(name: nameB ?? '…', isMe: mySide == 'B', won: !aWon, delta: match.eloDeltaB),
        ],
      ),
    );
  }
}

class _ResultSideRow extends StatelessWidget {
  final String name;
  final bool isMe;
  final bool won;
  final int? delta;

  const _ResultSideRow({required this.name, required this.isMe, required this.won, required this.delta});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: .spaceBetween,
      children: [
        Text(
          isMe ? '$name (You)' : name,
          style: TextStyle(fontWeight: won ? .bold : .normal, color: won ? Colors.green : null),
        ),
        if (delta != null)
          Text('${delta! > 0 ? '+' : ''}$delta elo', style: TextStyle(color: delta! > 0 ? Colors.green : Colors.red)),
      ],
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
              crossAxisAlignment: .start,
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

  (String, Color?) _labelAndColor(BuildContext context) => switch (status) {
    .scheduled => ('Upcoming', null),
    .inProgress => ('In progress', Colors.orange),
    .awaitingConfirmation => ('Awaiting confirmation', Colors.orange),
    .disputed => ('Disputed', Theme.of(context).colorScheme.error),
    .confirmed => ('Confirmed', Colors.green),
    .cancelled => ('Cancelled', null),
  };

  @override
  Widget build(BuildContext context) {
    final (label, color) = _labelAndColor(context);
    return Chip(
      shape: RoundedSuperellipseBorder(borderRadius: .circular(12)),
      label: Text(label),
      labelStyle: color != null ? TextStyle(color: color) : null,
      visualDensity: VisualDensity.compact,
    );
  }
}
