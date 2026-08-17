import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooper/data/providers.dart';
import 'package:hooper/models/match.dart';

class ViewMatchScreen extends ConsumerWidget {
  const ViewMatchScreen({super.key, required this.matchId});
  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final match = ref.watch(matchProvider(matchId));
    final uid = ref.watch(currentUserIdProvider);
    return match.when(
      data: (match) => buildWidget(context, match, uid),
      error: (e, __) {
        return Text(e.toString());
      },
      loading: () => const CircularProgressIndicator(),
    );
  }

  Widget buildWidget(BuildContext context, MatchDoc match, String uid) {
    final delta = match.myEloDelta(uid);
    final won = delta != null && delta > 0;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              won ? 'Victory!' : 'Match complete',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: won ? Colors.green : null),
            ),
            const SizedBox(height: 8),
            Text('${match.scoreA}–${match.scoreB}'),
            if (delta != null) ...[
              const SizedBox(height: 12),
              Text(
                '${delta > 0 ? '+' : ''}$delta elo',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: delta > 0 ? Colors.green : Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
