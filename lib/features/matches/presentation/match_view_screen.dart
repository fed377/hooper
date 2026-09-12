import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooper/core/utils/utils.dart';
import 'package:hooper/core/widgets/blurred_container.dart';
import 'package:hooper/core/widgets/custom_data_box.dart';
import 'package:hooper/core/widgets/skeleton_widget.dart';
import 'package:hooper/features/chat/data/chat.dart';
import 'package:hooper/features/chat/presentation/chat_screen.dart';
import 'package:hooper/features/discovery/data/matchup.dart';
import 'package:hooper/features/location/presentation/location_picker.dart';
import 'package:hooper/features/matches/data/match_repo.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mySide = match.mySide(uid);
    final isParticipant = mySide != null;

    final nameAAsync = ref.watch(playerDisplayNameProvider(match.sideAId));
    final nameBAsync = ref.watch(playerDisplayNameProvider(match.sideBId));
    final matchupAAsync = ref.watch(matchupFromIdProvider(match.sideAId));
    final matchupBAsync = ref.watch(matchupFromIdProvider(match.sideBId));

    final canCancel =
        isParticipant && (match.status == MatchStatus.scheduled || match.status == MatchStatus.inProgress);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          formatDateShort(match.scheduledTime),
          style: TextTheme.of(context).titleSmall?.copyWith(color: Colors.grey),
        ),
        Row(
          crossAxisAlignment: .center,
          children: [
            Flexible(
              child: _buildPlayerName(
                context,
                nameAAsync.when(data: (data) => data, error: (_, _) => 'ERROR', loading: () => '-----'),
                matchupAAsync.value,
              ),
            ),
            Text(' vs ', style: TextTheme.of(context).headlineMedium?.copyWith(fontWeight: .bold)),
            Flexible(
              child: _buildPlayerName(
                context,
                nameBAsync.when(data: (data) => data, error: (_, _) => 'ERROR', loading: () => '-----'),
                matchupBAsync.value,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: CustomDataBox(icon: Icons.place_rounded, value: match.court, label: 'Court')),
            const SizedBox(width: 16),
            Expanded(
              child: match.confirmedAt != null
                  ? CustomDataBox(
                      icon: Icons.schedule_outlined,
                      value: formatDuration(match.confirmedAt!.difference(match.scheduledTime)),
                      label: 'Duration',
                    )
                  : CustomDataBox(
                      icon: Icons.info_outline_rounded,
                      value: _statusLabel(match.status),
                      label: 'Status',
                    ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        LocationPicker.locationDisplayer(match.location),
        const SizedBox(height: 16),
        if (match.status == MatchStatus.confirmed) _buildResult(context, mySide, nameAAsync.value, nameBAsync.value),
        if (match.status == MatchStatus.cancelled) const Text('This match was cancelled.', textAlign: TextAlign.center),
        if (match.status == MatchStatus.scheduled)
          const Text("This match hasn't started yet.", textAlign: TextAlign.center),
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

  Widget _buildPlayerName(BuildContext context, String name, Matchup? matchup) {
    final style = TextTheme.of(context).headlineMedium?.copyWith(fontWeight: .bold);
    if (matchup == null || matchup.id == '') {
      return Text(name, style: style, overflow: TextOverflow.ellipsis);
    }
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MatchupViewScreen(matchup: matchup))),
      child: Text(
        name,
        style: style?.copyWith(decoration: TextDecoration.underline),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  String _statusLabel(MatchStatus status) => switch (status) {
    .scheduled => 'Scheduled',
    .awaitingConfirmation => 'Awaiting Confirmation',
    .confirmed => 'Confirmed',
    .disputed => 'Disputed',
    .cancelled => 'Cancelled',
    .inProgress => 'In Progress',
  };

  Widget _buildResult(BuildContext context, String? mySide, String? nameA, String? nameB) {
    final aWon = (match.scoreA ?? 0) > (match.scoreB ?? 0);
    return BlurredContainer(
      elevation: 2,
      radius: 24,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('${match.scoreA} – ${match.scoreB}', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            _ResultSideRow(name: nameA ?? '…', isMe: mySide == 'A', won: aWon, delta: match.eloDeltaA),
            const SizedBox(height: 6),
            _ResultSideRow(name: nameB ?? '…', isMe: mySide == 'B', won: !aWon, delta: match.eloDeltaB),
          ],
        ),
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
