import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooper/core/services/providers.dart';
import 'package:hooper/core/widgets/blurred_container.dart';
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
    final textTheme = TextTheme.of(context);
    return Padding(
      padding: .only(top: 12, bottom: 88, left: 12, right: 12),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MatchupViewScreen(matchup: match))),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: BlurredContainer(
            elevation: 1,
            child: RepaintBoundary(
              child: Padding(
                padding: const .symmetric(vertical: 16, horizontal: spacing),
                child: Column(
                  mainAxisSize: .min,
                  mainAxisAlignment: .end,
                  children: [
                    Row(
                      crossAxisAlignment: .center,
                      children: [
                        Text(match.displayName, style: textTheme.headlineMedium?.copyWith(fontWeight: .bold)),
                        if (match.id != '') ...[const Spacer(), _buildRecentForm(match), const SizedBox(width: 6)],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        EloRankChip(elo: match.elo),
                        const SizedBox(width: 12),
                        Text("${match.elo} ELO", style: textTheme.labelLarge?.copyWith(color: Colors.black)),
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
                            child: Text(widget.hasChallengedYou ? "Accept" : "Play", style: TextStyle(fontSize: 16)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ).asHero("mainchip"),
        ),
      ),
    );
  }

  MenuAnchor _buildMenuAnchor(FirestorePreferencesRepository repo, BuildContext context, Matchup match) {
    return MenuAnchor(
      consumeOutsideTap: true,
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

  Widget _buildRecentForm(Matchup match) {
    return CustomPaint(
      size: Size((match.recentForm.length * 12).toDouble(), 15),
      painter: RecentFormPainter(recentForm: match.recentForm),
    );
  }
}

class RecentFormPainter extends CustomPainter {
  final List<bool> recentForm;

  RecentFormPainter({required this.recentForm});

  @override
  void paint(Canvas canvas, Size size) {
    if (recentForm.isEmpty) return;

    final double itemWidth = 10.0;
    final double spacing = 2.0;
    final double height = size.height;

    for (int i = 0; i < recentForm.length; i++) {
      final isWin = recentForm[i];
      final paint = Paint()
        ..color = isWin ? Colors.green : Colors.red
        ..style = PaintingStyle.fill;

      final double left = i * (itemWidth + spacing);
      final rect = Rect.fromLTWH(left, 0, itemWidth, height);

      final double leftRadius = (i == 0) ? 8.0 : 2.0;
      final double rightRadius = (i == recentForm.length - 1) ? 8.0 : 2.0;

      final rrect = RRect.fromRectAndCorners(
        rect,
        topLeft: Radius.circular(leftRadius),
        bottomLeft: Radius.circular(leftRadius),
        topRight: Radius.circular(rightRadius),
        bottomRight: Radius.circular(rightRadius),
      );

      canvas.drawRRect(rrect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant RecentFormPainter oldDelegate) {
    return oldDelegate.recentForm != recentForm;
  }
}
