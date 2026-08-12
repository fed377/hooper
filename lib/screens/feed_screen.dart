import 'dart:developer' show log;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooper/models/chat.dart';
import 'package:hooper/models/matchup.dart';
import 'package:hooper/screens/chat_screen.dart';
import 'package:hooper/screens/propose_screen.dart';

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
      body: matchupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) {
          log(err.toString());
          return Center(
            child: Padding(padding: const EdgeInsets.all(24), child: Text('Could not load nearby players: $err')),
          );
        },
        data: (matchups) {
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

          return PageView.builder(
            physics: BouncingScrollPhysics(),
            itemCount: matchups.length,
            scrollDirection: Axis.vertical,
            itemBuilder: (context, index) {
              final matchup = matchups[index];
              final incomingRequestId = incomingByInitiator[matchup.id];

              return MatchupCard(
                matchup: matchup,
                hasChallengedYou: incomingRequestId != null,
                onChallenge: () => showModalBottomSheet(
                  showDragHandle: true,
                  context: context,
                  builder: (context) {
                    return ProposeMatchScreen(target: matchup);
                  },
                ),
                onAccept: incomingRequestId == null
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            chatId: incomingRequestId,
                            onPropose: () => Navigator.of(
                              context,
                            ).push(MaterialPageRoute(builder: (_) => ProposeMatchScreen(target: matchup))),
                          ),
                        ),
                      ),
                onChat: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      chatId: Chat.pairChatId(matchup.id, ref.read(currentUserIdProvider)),
                      onPropose: () => Navigator.of(
                        context,
                      ).push(MaterialPageRoute(builder: (_) => ProposeMatchScreen(target: matchup))),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
