import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooper/core/services/providers.dart';
import 'package:hooper/core/utils/utils.dart';
import 'package:hooper/core/widgets/blurred_container.dart';
import 'package:hooper/core/widgets/skeleton_widget.dart';
import 'package:hooper/features/discovery/data/matchup.dart';
import 'package:hooper/features/matches/data/match_doc.dart';
import 'package:hooper/features/matches/presentation/match_list_tile.dart';

class MatchesList extends ConsumerWidget {
  const new({
    super.key,
    required this.matchesAsync,
    required this.userId,
    required this.label,
    this.includeBlurredContainer = true,
  });

  final AsyncValue<List<String>> matchesAsync;
  final String userId;
  final String label;
  final bool includeBlurredContainer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = HooprColors.instance;
    return SkeletonWidget(
      val: matchesAsync,
      dummyData: List.generate(2, (_) => ''),
      builder: (matches) {
        if ((matches.isNotEmpty)) {
          var list = Padding(
            padding: const .only(left: 16, right: 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height / 3),
              child: Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 16),
                child: ClipRSuperellipse(
                  borderRadius: .circular(34 - 16),
                  child: Column(
                    mainAxisSize: .min,
                    children: [
                      Center(
                        child: Text(label, style: TextTheme.of(context).titleMedium?.copyWith(fontWeight: .w600)),
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: Container(
                          decoration: ShapeDecoration(
                            shape: RoundedSuperellipseBorder(borderRadius: .circular(34 - 16)),
                            color: colors.darkenColor,
                          ),
                          child: ListView.builder(
                            primary: true,
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: matches.length,
                            itemBuilder: (context, i) {
                              final matchId = matches[i];
                              if (matchId == '') {
                                return Padding(
                                  padding: EdgeInsets.only(bottom: i == matches.length - 1 ? 0 : 10),
                                  child: MatchListTile(
                                    match: MatchDoc.dummy(),
                                    radius: 34 - 16,
                                    matchup: Matchup.dummy(),
                                  ),
                                );
                              }
                              final matchAsync = ref.watch(matchAndMatchupProvider((matchId, userId)));
                              return SkeletonWidget(
                                val: matchAsync,
                                dummyData: MatchOpponent.dummy(),
                                builder: (MatchOpponent data) {
                                  return Padding(
                                    padding: EdgeInsets.only(bottom: i == matches.length - 1 ? 0 : 10),
                                    child: MatchListTile(match: data.match, matchup: data.matchup, radius: 34 - 16),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          if (includeBlurredContainer) {
            return BlurredContainer(elevation: 2, sigma: 0, child: list);
          } else {
            return list;
          }
        } else {
          var list = Padding(
            padding: const .only(left: 16, right: 16),
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height / 6,
              child: Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 16),
                child: ClipRSuperellipse(
                  borderRadius: .circular(34 - 16),
                  child: Column(
                    mainAxisSize: .min,
                    children: [
                      Center(
                        child: Text(label, style: TextTheme.of(context).titleMedium?.copyWith(fontWeight: .w600)),
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: Container(
                          decoration: ShapeDecoration(
                            shape: RoundedSuperellipseBorder(borderRadius: .circular(34 - 12)),
                            color: colors.darkenColor,
                          ),
                          child: Center(child: Text('None.')),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          if (includeBlurredContainer) {
            return BlurredContainer(elevation: 2, sigma: 0, child: list);
          } else {
            return list;
          }
        }
      },
    );
  }
}
