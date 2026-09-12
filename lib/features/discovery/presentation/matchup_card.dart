import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooper/core/services/providers.dart';
import 'package:hooper/core/utils/utils.dart';
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
  ButtonStyle get _tintedIconStyle => IconButton.styleFrom(
    backgroundColor: HooprColors.instance.darkenColor,
    foregroundColor: Colors.black,
    shape: CircleBorder(),
    minimumSize: Size(0, 50),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    padding: EdgeInsets.all(12),
  );

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
                        IconButton(
                          style: _tintedIconStyle,
                          icon: Icon(Icons.chat_bubble_rounded, size: 24),
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
        return IconButton(
          style: _tintedIconStyle,
          icon: Icon(Icons.more_horiz_rounded, size: 24),
          onPressed: () {
            controller.isOpen ? controller.close() : controller.open();
          },
        );
      },
    );
  }

  Widget _buildRecentForm(Matchup match) {
    return _RecentFormRow(form: match.recentForm);
  }
}

class _RecentFormRow extends StatefulWidget {
  const _RecentFormRow({required this.form});
  final List<bool> form;

  @override
  State<_RecentFormRow> createState() => _RecentFormRowState();
}

class _RecentFormRowState extends State<_RecentFormRow> with SingleTickerProviderStateMixin {
  static const double _itemWidth = 10;
  static const double _spacing = 2;
  static const double _height = 15;

  late AnimationController _controller;
  late List<bool> _previousForm;
  late List<bool> _currentForm;

  @override
  void initState() {
    super.initState();
    _previousForm = widget.form;
    _currentForm = widget.form;
    _controller = AnimationController(vsync: this, duration: Durations.medium2, value: 1);
  }

  @override
  void didUpdateWidget(covariant _RecentFormRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameForm(widget.form, _currentForm)) {
      _previousForm = _currentForm;
      _currentForm = widget.form;
      _controller.forward(from: 0);
    }
  }

  bool _sameForm(List<bool> a, List<bool> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  double _widthFor(int length) => length == 0 ? 0 : length * _itemWidth + (length - 1) * _spacing;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxLen = math.max(_previousForm.length, _currentForm.length);
    final maxWidth = _widthFor(maxLen);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_controller.value);
        final fromWidth = _widthFor(_previousForm.length);
        final toWidth = _widthFor(_currentForm.length);
        final visibleWidth = fromWidth + (toWidth - fromWidth) * t;

        return SizedBox(
          width: maxWidth,
          height: _height,
          child: Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: visibleWidth,
              height: _height,
              child: ClipRSuperellipse(
                borderRadius: .circular(8),
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: List.generate(maxLen, (i) {
                    final d = maxLen - 1 - i;
                    final prevExists = d < _previousForm.length;
                    final currExists = d < _currentForm.length;
                    final prevColor = prevExists
                        ? (_previousForm[_previousForm.length - 1 - d] ? Colors.green : Colors.red)
                        : null;
                    final currColor = currExists
                        ? (_currentForm[_currentForm.length - 1 - d] ? Colors.green : Colors.red)
                        : null;
                    final fromColor = prevColor ?? currColor!.withAlpha(0);
                    final toColor = currColor ?? prevColor!.withAlpha(0);
                    final color = Color.lerp(fromColor, toColor, t)!;
                    return Positioned(
                      right: d * (_itemWidth + _spacing),
                      width: _itemWidth,
                      height: _height,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: color, borderRadius: .circular(2)),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
