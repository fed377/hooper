import 'dart:developer' show log;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooper/screens/propose_screen.dart';

import '../../data/providers.dart';
import '../../widgets/matchup_card.dart';

class MatchupFeedScreen extends ConsumerWidget {
  const MatchupFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchupsAsync = ref.watch(nearbyMatchupsProvider);

    return Scaffold(
      body: matchupsAsync.when(
        // AsyncValue.when replaces the manual _loading bool and
        // try/catch from the setState version — loading, error, and
        // empty are now just states of the stream, not things we track
        // by hand.
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) {
          log(stack.toString());
          return Center(
            child: Padding(padding: const EdgeInsets.all(24), child: Text('Could not load nearby players: $err')),
          );
        },
        data: (matchups) {
          if (matchups.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.sports_basketball_outlined, size: 48),
                    const SizedBox(height: 12),
                    const Text('No one nearby right now'),
                    const SizedBox(height: 4),
                    Text('Try widening your search radius in Settings.', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            );
          }

          return PageView.builder(
            physics: BouncingScrollPhysics(),
            itemCount: matchups.length,
            scrollDirection: Axis.vertical,
            itemBuilder: (context, index) {
              final matchup = matchups[index];
              return MatchupCard(
                matchup: matchup,
                onChallenge: () => showModalBottomSheet(
                  showDragHandle: true,
                  context: context,
                  builder: (context) {
                    return ProposeMatchScreen(target: matchup);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
