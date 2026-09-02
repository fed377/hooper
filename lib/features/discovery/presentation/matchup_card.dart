import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooper/core/services/providers.dart';
import 'package:hooper/core/widgets/dark_buttons.dart';
import 'package:hooper/core/widgets/elo_rank_chip.dart';
import 'package:hooper/features/discovery/data/matchup.dart';
import 'package:hooper/features/profile/data/preferences_repo.dart';
import 'package:hooper/features/requests/presentation/matchup_view_screen.dart';

class MatchupCard extends ConsumerStatefulWidget {
  const MatchupCard({
    super.key,
    required this.matchup,
    required this.onChallenge,
    required this.onAccept,
    required this.onChat,
    required this.myId,
    this.hasChallengedYou = false,
  });
  final Matchup matchup;
  final bool hasChallengedYou;
  final void Function() onChallenge;
  final void Function()? onAccept;
  final void Function() onChat;
  final String myId;

  @override
  ConsumerState<MatchupCard> createState() => _MatchupCardState();
}

class _MatchupCardState extends ConsumerState<MatchupCard> {
  @override
  Widget build(BuildContext context) {
    const double spacing = 14;
    Matchup match = widget.matchup;
    match.tier;
    final repo = ref.watch(preferencesRepoProvider);
    final blurSigma = 12.0;
    return Padding(
      padding: .only(top: 12, bottom: 88, left: 12, right: 12),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MatchupViewScreen(matchup: match))),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Hero(
            tag: "mainchip",
            flightShuttleBuilder: (flightContext, animation, flightDirection, fromHeroContext, toHeroContext) {
              return SingleChildScrollView(physics: const NeverScrollableScrollPhysics(), child: toHeroContext.widget);
            },
            child: Material(
              type: MaterialType.transparency,
              child: ClipRSuperellipse(
                borderRadius: .circular(36),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
                  child: Container(
                    decoration: ShapeDecoration(
                      color: const Color.fromARGB(125, 255, 255, 255),
                      shape: RoundedSuperellipseBorder(borderRadius: .circular(32)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: spacing),
                      child: Column(
                        mainAxisSize: .min,
                        mainAxisAlignment: .end,
                        children: [
                          Row(
                            crossAxisAlignment: .center,
                            children: [
                              Text(
                                match.displayName,
                                style: TextTheme.of(context).headlineMedium?.copyWith(fontWeight: .bold),
                              ),
                              if (match.id != '') ...[
                                const Spacer(),
                                const SizedBox(width: 6),
                                ..._buildRecentForm(match),
                                const SizedBox(width: 6),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              EloRankChip(elo: match.elo),
                              const SizedBox(width: 12),
                              Text(
                                "${match.elo} ELO",
                                style: TextTheme.of(context).labelLarge?.copyWith(color: Colors.black),
                              ),
                              const Spacer(),
                              Text("${match.distanceKm} km away"),
                            ],
                          ),
                          const SizedBox(height: spacing),
                          Row(
                            mainAxisSize: .max,
                            crossAxisAlignment: .end,
                            mainAxisAlignment: .spaceBetween,
                            children: [
                              _buildMenuAnchor(repo, context, match),
                              const SizedBox(width: spacing),
                              IconButton.filledTonal(
                                style: ElevatedButton.styleFrom(
                                  shape: CircleBorder(),
                                  minimumSize: Size(0, 50),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  padding: EdgeInsets.all(14),
                                ),
                                icon: Icon(Icons.chat_bubble_rounded, size: 20),
                                onPressed: widget.onChat,
                              ),
                              const SizedBox(width: spacing),
                              Expanded(
                                child: DarkFilledButton(
                                  shadow: false,
                                  onPressed: widget.hasChallengedYou ? widget.onAccept : widget.onChallenge,
                                  child: Text(
                                    widget.hasChallengedYou ? "Accept" : "Play",
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  MenuAnchor _buildMenuAnchor(FirestorePreferencesRepository repo, BuildContext context, Matchup match) {
    return MenuAnchor(
      alignmentOffset: Offset(-10, -70),
      menuChildren: [
        MenuItemButton(
          onPressed: () async {
            final b = await repo.confirmBlockUser(context, widget.myId, match.id, match.displayName);
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
            final b = await repo.confirmReportUser(context, widget.myId, match.id, null, match.displayName);
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

  List<Widget> _buildRecentForm(Matchup match) {
    return List.generate(
      match.recentForm.length,
      (index) => Container(
        margin: EdgeInsets.all(1),
        height: 15,
        width: 10,
        decoration: BoxDecoration(
          color: !match.recentForm[index] ? Colors.red : Colors.green,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(index == 0 ? 8 : 2),
            bottomLeft: Radius.circular(index == 0 ? 8 : 2),
            topRight: Radius.circular(index == match.recentForm.length - 1 ? 8 : 2),
            bottomRight: Radius.circular(index == match.recentForm.length - 1 ? 8 : 2),
          ),
        ),
      ),
    );
  }
}
