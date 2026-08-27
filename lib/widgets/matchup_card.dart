import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooper/data/providers.dart';
import 'package:hooper/models/matchup.dart';
import 'package:hooper/screens/matchup_view_screen.dart';
import 'package:hooper/widgets/elo_rank_chip.dart';
import 'package:progressive_blur/progressive_blur.dart';

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

    return Padding(
      padding: const EdgeInsets.only(top: 46, left: 12, right: 12, bottom: 12),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MatchupViewScreen(matchup: match))),
        child: ClipRSuperellipse(
          borderRadius: BorderRadius.circular(44),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: (match.id == '')
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
                          child: widget.matchup.bannerUrl == null || widget.matchup.bannerUrl == ''
                              ? Center(child: Icon(Icons.question_mark_rounded))
                              : ClipRSuperellipse(
                                  borderRadius: BorderRadius.circular(44),
                                  child: Image.network(widget.matchup.bannerUrl!, fit: BoxFit.cover),
                                ),
                        ),
                      ),
              ),
              Padding(
                padding: EdgeInsets.only(top: 12, bottom: 12, left: 12, right: 12),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Hero(
                    tag: "mainchip",
                    flightShuttleBuilder: (flightContext, animation, flightDirection, fromHeroContext, toHeroContext) {
                      return SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: toHeroContext.widget,
                      );
                    },
                    child: Material(
                      type: MaterialType.transparency,
                      child: Container(
                        decoration: ShapeDecoration(
                          color: Colors.white,
                          shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(32)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: spacing),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    match.displayName,
                                    style: TextTheme.of(context).headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  if (match.id != '') ...[
                                    const Spacer(),
                                    EloRankChip(elo: match.elo),
                                    const SizedBox(width: 6),
                                    ..._buildRecentForm(match),
                                    const SizedBox(width: 6),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    "${match.elo} ELO",
                                    style: TextTheme.of(context).labelLarge?.copyWith(color: Colors.grey),
                                  ),
                                  const Spacer(),
                                  Text("${match.distanceKm} km away"),
                                ],
                              ),
                              const SizedBox(height: spacing),
                              Row(
                                mainAxisSize: MainAxisSize.max,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  MenuAnchor(
                                    alignmentOffset: Offset(-10, -70),
                                    menuChildren: [
                                      MenuItemButton(
                                        onPressed: () async {
                                          final b = await repo.confirmBlockUser(
                                            context,
                                            widget.myId,
                                            match.id,
                                            match.displayName,
                                          );
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
                                            widget.myId,
                                            match.id,
                                            null,
                                            match.displayName,
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
                                      shape: WidgetStatePropertyAll(
                                        RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(24)),
                                      ),
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
                                    child: FilledButton(
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: Size(0, 50),
                                        shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(24)),
                                      ),
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
            ],
          ),
        ),
      ),
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
