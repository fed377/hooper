import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooper/core/services/providers.dart';
import 'package:hooper/core/utils/utils.dart';
import 'package:hooper/core/widgets/blurred_container.dart';
import 'package:hooper/core/widgets/elo_rank_chip.dart';
import 'package:hooper/features/chat/data/chat.dart';
import 'package:hooper/features/chat/presentation/chat_screen.dart';
import 'package:hooper/features/discovery/data/matchup.dart';
import 'package:hooper/features/profile/data/player_profile.dart';
import 'package:hooper/features/profile/data/preferences_repo.dart';

import '../../../core/widgets/custom_data_box.dart';
import '../../matches/presentation/matches_list.dart';

class MatchupViewScreen extends ConsumerWidget {
  final Matchup matchup;
  const MatchupViewScreen({super.key, required this.matchup});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completedMatchesAsync = ref.watch(completedMatchesProvider(matchup.id));
    final repo = ref.watch(preferencesRepoProvider);
    final myId = ref.read(currentUserIdProvider);
    return Scaffold(
      body: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: (matchup.id == '')
                  ? Container(color: Theme.of(context).colorScheme.surfaceContainerHighest)
                  : Hero(
                      transitionOnUserGestures: true,
                      tag: "banner_${matchup.id}",
                      child: matchup.bannerUrl == null || matchup.bannerUrl == ''
                          ? Center(child: Icon(Icons.question_mark_rounded))
                          : Image(image: ref.read(imageProviderFamily(matchup.bannerUrl!)), fit: .cover),
                    ),
            ),
          ),
          Align(
            alignment: .topCenter,
            child: Padding(
              padding: const .symmetric(horizontal: 16.0),
              child: IntrinsicHeight(
                child: AppBar(
                  backgroundColor: Colors.transparent,
                  actions: [
                    IconButton.filledTonal(
                      style: ElevatedButton.styleFrom(
                        shape: CircleBorder(),
                        minimumSize: Size(0, 50),
                        tapTargetSize: .shrinkWrap,
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
                    _buildMenuAnchor(repo, context, myId, ref),
                  ],
                ),
              ),
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const .only(top: 12, bottom: 12, left: 12, right: 12),
              child: BlurredContainer(
                elevation: 1, 
                radius: ref
                    .read(cornerRadiusProvider)
                    .when(data: (data) => data, error: (_, _) => 36, loading: () => 36.0),
                child: Padding(
                  padding: const .symmetric(vertical: 16, horizontal: 14),
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
                      const SizedBox(height: 14),
                      ..._buildDataBoxes(context, completedMatchesAsync),
                    ],
                  ),
                ),
              ).asHero("mainchip"),
            ),
          ),
        ],
      ),
    );
  }

  MenuAnchor _buildMenuAnchor(FirestorePreferencesRepository repo, BuildContext context, String myId, WidgetRef ref) {
    return MenuAnchor(
      consumeOutsideTap: true,
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
            final b = await repo.confirmReportUser(context, myId, matchup.id, null, matchup.displayName);
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
    );
  }

  List<Widget> _buildDataBoxes(BuildContext context, AsyncValue<List<String>> completedMatchesAsync) {
    const double spacing = 12;

    return [
      Row(
        children: [
          Expanded(
            child: CustomDataBox(value: matchup.elo.toString(), icon: Icons.leaderboard_rounded, label: "Elo"),
          ),
          const SizedBox(width: spacing),
          Expanded(
            child: CustomDataBox(
              value: matchup.distanceKm.toString(),
              icon: Icons.location_on_rounded,
              label: "Km away",
            ),
          ),
        ],
      ),
      const SizedBox(height: spacing),
      Row(
        children: [
          Expanded(
            child: CustomDataBox(value: matchup.height.toString(), icon: Icons.height_rounded, label: "Height"),
          ),
          const SizedBox(width: spacing),
          Expanded(
            child: CustomDataBox(
              value: capitalize(playerPositionFromInt(matchup.position)?.name),
              icon: Icons.person_2_rounded,
              label: "Position",
            ),
          ),
        ],
      ),
      const SizedBox(height: spacing),
      MatchesList(matchesAsync: completedMatchesAsync, userId: matchup.id, label: "Finished Matches"),
    ];
  }
}
