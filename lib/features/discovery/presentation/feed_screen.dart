import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooper/core/widgets/skeleton_widget.dart';
import 'package:hooper/features/chat/data/chat.dart';
import 'package:hooper/features/chat/presentation/chat_screen.dart';
import 'package:hooper/features/discovery/data/matchup.dart';
import 'package:hooper/features/requests/presentation/matchup_view_screen.dart';
import 'package:hooper/features/requests/presentation/propose_screen.dart';

import '../../../core/services/providers.dart';
import 'matchup_card.dart';

class MatchupFeedScreen extends ConsumerStatefulWidget {
  const MatchupFeedScreen({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() {
    return MatchupFeedScreenState();
  }
}

class MatchupFeedScreenState extends ConsumerState<MatchupFeedScreen> {
  int _currIndex = 0;

  @override
  Widget build(BuildContext context) {
    final matchupsAsync = ref.watch(nearbyMatchupsProvider);
    final incomingAsync = ref.watch(incomingRequestsProvider);
    final outgoingAsync = ref.watch(outgoingRequestsProvider);

    return Scaffold(
      extendBody: true,
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
                  mainAxisSize: .min,
                  children: [
                    const Icon(Icons.sports_basketball_outlined, size: 48),
                    const SizedBox(height: 12),
                    const Text('No one nearby right now'),
                    const SizedBox(height: 4),
                    Text('Try widening your search radius in Settings.', style: Theme.of(context).textTheme.bodySmall),
                    IconButton(
                      icon: Icon(Icons.refresh_rounded),
                      onPressed: () async {
                        nearbyMatchupsProvider.overrideWithValue(AsyncValue.data([]));
                        ref.invalidate(nearbyMatchupsProvider);
                      },
                    ),
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
            child: Stack(
              children: [
                SizedBox.expand(
                  child: PageView.builder(
                    physics: const ClampingScrollPhysics(),
                    itemCount: matchups.length,
                    scrollDirection: Axis.vertical,
                    itemBuilder: (context, index) {
                      final matchup = matchups[index];
                      return (matchup.id == '')
                          ? Container(color: Theme.of(context).colorScheme.surfaceContainerHighest)
                          : Hero(
                              tag: "banner",
                              child: matchup.bannerUrl == null || matchup.bannerUrl == ''
                                  ? Center(child: Icon(Icons.question_mark_rounded))
                                  : GestureDetector(
                                      onTap: () => Navigator.of(context)
                                          .push(MaterialPageRoute(builder: (_) => MatchupViewScreen(matchup: matchup))),
                                      child: Image.network(matchup.bannerUrl!, fit: BoxFit.cover),
                                    ),
                            );
                    },
                    onPageChanged: (i) => setState(() => _currIndex = i),
                  ),
                ),
                _buildMatchupCard(matchups[_currIndex], context, ref, incomingByInitiator[matchups[_currIndex].id]),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMatchupCard(Matchup matchup, BuildContext context, WidgetRef ref, String? incomingRequestId) {
    return MatchupCard(
      matchup: matchup,
      hasChallengedYou: incomingRequestId != null,
      onChallenge: () => ProposeMatchScreen.pushProposal(matchup.id, context),
      onAccept: incomingRequestId == null
          ? null
          : () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChatScreen(chatId: Chat.pairChatId(matchup.id, ref.read(currentUserIdProvider))),
              ),
            ),
      myId: ref.read(currentUserIdProvider),
      onChat: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(chatId: Chat.pairChatId(matchup.id, ref.read(currentUserIdProvider))),
        ),
      ),
    );
  }
}
