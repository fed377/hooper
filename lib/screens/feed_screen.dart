import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooper/models/chat.dart';
import 'package:hooper/models/matchup.dart';
import 'package:hooper/screens/chat_screen.dart';
import 'package:hooper/screens/propose_screen.dart';
import 'package:hooper/widgets/skeleton_widget.dart';

import '../../data/providers.dart';
import '../../widgets/matchup_card.dart';

class MatchupFeedScreen extends ConsumerWidget {
  const MatchupFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchupsAsync = ref.watch(nearbyMatchupsProvider);
    final incomingAsync = ref.watch(incomingRequestsProvider);
    final outgoingAsync = ref.watch(outgoingRequestsProvider);

    return Scaffold(
      body: SkeletonWidget<List<Matchup>>(
        val: matchupsAsync,
        dummyData: [Matchup.dummy()],
        builder: (List<Matchup> matchups) {
          final outgoingByTarget = {for (final req in outgoingAsync.value ?? const []) req.targetId: req.id};

          List<Matchup> toRemove = [];
          for (final x in matchups) {
            if (outgoingByTarget[x.id] != null) {
              toRemove.add(x);
            }
          }

          for (final x in toRemove) {
            matchups.remove(x);
          }

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

          final incomingByInitiator = {for (final req in incomingAsync.value ?? const []) req.initiatorId: req.id};

          return RefreshIndicator(
            onRefresh: () async {
              nearbyMatchupsProvider.overrideWithValue(AsyncValue.data([]));
              ref.invalidate(nearbyMatchupsProvider);
            },
            child: PageView.builder(
              physics: const ClampingScrollPhysics(),
              itemCount: matchups.length,
              scrollDirection: Axis.vertical,
              itemBuilder: (context, index) {
                final matchup = matchups[index];
                final incomingRequestId = incomingByInitiator[matchup.id];

                return MatchupCard(
                  matchup: matchup,
                  hasChallengedYou: incomingRequestId != null,
                  onChallenge: () => ProposeMatchScreen.pushProposal(matchup.id, context),
                  onAccept: incomingRequestId == null
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                ChatScreen(chatId: Chat.pairChatId(matchup.id, ref.read(currentUserIdProvider))),
                          ),
                        ),
                  myId: ref.read(currentUserIdProvider),
                  onChat: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(chatId: Chat.pairChatId(matchup.id, ref.read(currentUserIdProvider))),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
