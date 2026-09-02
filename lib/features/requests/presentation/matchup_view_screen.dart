import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooper/core/services/providers.dart';
import 'package:hooper/core/widgets/elo_rank_chip.dart';
import 'package:hooper/core/widgets/skeleton_widget.dart';
import 'package:hooper/features/chat/data/chat.dart';
import 'package:hooper/features/chat/presentation/chat_screen.dart';
import 'package:hooper/features/discovery/data/matchup.dart';
import 'package:hooper/features/matches/data/match_doc.dart';
import 'package:hooper/features/matches/presentation/match_list_tile.dart';
import 'package:progressive_blur/progressive_blur.dart';

class MatchupViewScreen extends ConsumerWidget {
  final Matchup matchup;
  const MatchupViewScreen({super.key, required this.matchup});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completedMatchesAsync = ref.watch(completedMatchesProvider(matchup.id));
    final repo = ref.watch(preferencesRepoProvider);
    final myId = ref.read(currentUserIdProvider);
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.only(top: 46, left: 12, right: 12, bottom: 12),
        child: ClipRSuperellipse(
          borderRadius: .circular(44),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: (matchup.id == '')
                    ? Container(color: Theme.of(context).colorScheme.surfaceContainerHighest)
                    : Hero(
                        tag: "banner",
                        child: ProgressiveBlurWidget(
                          sigma: 24,
                          linearGradientBlur: LinearGradientBlur(
                            values: [1, 0.8, 0],
                            stops: [0, 0.3, 0.55],
                            start: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                          child: matchup.bannerUrl == null || matchup.bannerUrl == ''
                              ? Center(child: Icon(Icons.question_mark_rounded))
                              : ClipRSuperellipse(
                                  borderRadius: .circular(44),
                                  child: Image.network(matchup.bannerUrl!, fit: BoxFit.cover),
                                ),
                        ),
                      ),
              ),
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisSize: .min,
                    mainAxisAlignment: .end,
                    children: [
                      IconButton.filledTonal(
                        style: ElevatedButton.styleFrom(
                          shape: CircleBorder(),
                          minimumSize: Size(0, 50),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: EdgeInsets.all(14),
                        ),
                        icon: Icon(Icons.chat_bubble_rounded, size: 20),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                ChatScreen(chatId: Chat.pairChatId(matchup.id, ref.read(currentUserIdProvider))),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      MenuAnchor(
                        alignmentOffset: Offset(-10, -70),
                        menuChildren: [
                          MenuItemButton(
                            onPressed: () async {
                              final b = await repo.confirmBlockUser(context, myId, matchup.id, matchup.displayName);
                              if (b) {
                                ref.invalidate(nearbyMatchupsProvider);
                              }
                            },
                            child: Row(
                              children: [
                                const Icon(Icons.block_rounded, color: Colors.red),
                                const SizedBox(width: 8),
                                const Text('Block User'),
                              ],
                            ),
                          ),
                          MenuItemButton(
                            onPressed: () async {
                              final b = await repo.confirmReportUser(
                                context,
                                myId,
                                matchup.id,
                                null,
                                matchup.displayName,
                              );
                              if (b) {
                                ref.invalidate(nearbyMatchupsProvider);
                              }
                            },
                            child: Row(
                              children: [
                                const Icon(Icons.block_rounded, color: Colors.red),
                                const SizedBox(width: 8),
                                const Text('Report User'),
                              ],
                            ),
                          ),
                        ],
                        style: MenuStyle(
                          alignment: Alignment.bottomCenter,
                          elevation: WidgetStatePropertyAll(0),
                          shape: WidgetStatePropertyAll(RoundedSuperellipseBorder(borderRadius: .circular(24))),
                        ),
                        builder: (context, controller, child) {
                          return IconButton.filledTonal(
                            style: ElevatedButton.styleFrom(
                              shape: CircleBorder(),
                              minimumSize: Size(0, 50),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              padding: EdgeInsets.all(12),
                            ),
                            icon: Icon(Icons.more_horiz_rounded, size: 24),
                            onPressed: () {
                              controller.isOpen ? controller.close() : controller.open();
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Hero(
                  tag: "mainchip",
                  child: Material(
                    type: MaterialType.transparency,
                    child: Container(
                      decoration: ShapeDecoration(
                        color: Colors.white,
                        shape: RoundedSuperellipseBorder(borderRadius: .circular(32)),
                      ),
                      child: Padding(
                        padding: const .symmetric(vertical: 16, horizontal: 14),
                        child: OverflowBox(
                          fit: .deferToChild,
                          child: Column(
                            mainAxisSize: .min,
                            mainAxisAlignment: .end,
                            children: [
                              Row(
                                crossAxisAlignment: .center,
                                children: [
                                  Text(
                                    matchup.displayName,
                                    style: TextTheme.of(context).headlineMedium?.copyWith(fontWeight: .bold),
                                  ),
                                  if (matchup.id != '') ...[const Spacer(), EloRankChip(elo: matchup.elo)],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    "${matchup.elo} ELO",
                                    style: TextTheme.of(context).labelLarge?.copyWith(color: Colors.grey),
                                  ),
                                  const Spacer(),
                                  Text("${matchup.distanceKm} km away"),
                                ],
                              ),
                              const SizedBox(height: 14),
                              SkeletonWidget(
                                val: completedMatchesAsync,
                                dummyData: List.generate(2, (_) => ''),
                                builder: (completedMatches) {
                                  if ((completedMatches.isNotEmpty)) {
                                    return Container(
                                      padding: EdgeInsets.only(left: 16, right: 16),
                                      decoration: ShapeDecoration(
                                        color: Theme.of(context).colorScheme.surfaceContainer,
                                        shape: RoundedSuperellipseBorder(borderRadius: .circular(34)),
                                      ),
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height / 3),
                                        child: Padding(
                                          padding: const EdgeInsets.only(top: 16, bottom: 16),
                                          child: ClipRSuperellipse(
                                            borderRadius: .circular(34 - 16),
                                            child: ListView.builder(
                                              primary: true,
                                              padding: EdgeInsets.zero,
                                              shrinkWrap: true,
                                              itemCount: completedMatches.length,
                                              itemBuilder: (context, i) {
                                                final matchId = completedMatches[i];
                                                if (matchId == '') {
                                                  return Padding(
                                                    padding: EdgeInsets.only(
                                                      bottom: i == completedMatches.length - 1 ? 0 : 10,
                                                    ),
                                                    child: MatchListTile(
                                                      match: MatchDoc.dummy(),
                                                      radius: 34 - 16,
                                                      matchup: Matchup.dummy(),
                                                    ),
                                                  );
                                                }
                                                final matchAsync = ref.watch(
                                                  matchAndMatchupProvider((matchId, matchup.id)),
                                                );
                                                return SkeletonWidget(
                                                  val: matchAsync,
                                                  dummyData: MatchOpponent.dummy(),
                                                  builder: (MatchOpponent data) {
                                                    return Padding(
                                                      padding: EdgeInsets.only(
                                                        bottom: i == completedMatches.length - 1 ? 0 : 10,
                                                      ),
                                                      child: MatchListTile(
                                                        match: data.match,
                                                        matchup: data.matchup,
                                                        radius: 34 - 16,
                                                      ),
                                                    );
                                                  },
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  } else {
                                    return Padding(padding: const EdgeInsets.all(8.0), child: Text("No matches yet. "));
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
