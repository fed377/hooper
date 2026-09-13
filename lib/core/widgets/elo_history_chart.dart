import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooper/core/services/providers.dart';
import 'package:hooper/core/widgets/blurred_container.dart';
import 'package:hooper/core/widgets/skeleton_widget.dart';
import 'package:hooper/features/profile/data/elo_history.dart';

/// A small line-chart card showing a player's recent rated-match ELO swings.
/// Works for any [uid], not just the signed-in user — matches (and their
/// resulting rating deltas) are third-party visible in this app.
class EloHistoryChart extends ConsumerWidget {
  const EloHistoryChart({
    super.key,
    required this.uid,
    this.fallbackElo,
    this.chartHeight = 120,
  });

  final String uid;
  final int? fallbackElo;
  final double chartHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(eloHistoryProvider(uid));

    return BlurredContainer(
      elevation: 1,
      radius: 28,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: SkeletonWidget<List<EloHistoryEntry>>(
          val: historyAsync,
          dummyData: List.generate(
            8,
            (i) => EloHistoryEntry.dummy(1200 + ((i * 37) % 80) - 40),
          ),
          builder: (entries) => _EloHistoryBody(
            entries: entries,
            fallbackElo: fallbackElo,
            chartHeight: chartHeight,
          ),
        ),
      ),
    );
  }
}

class _EloHistoryBody extends StatefulWidget {
  const _EloHistoryBody({
    required this.entries,
    required this.fallbackElo,
    required this.chartHeight,
  });

  final List<EloHistoryEntry> entries;
  final int? fallbackElo;
  final double chartHeight;

  @override
  State<_EloHistoryBody> createState() => _EloHistoryBodyState();
}

class _EloHistoryBodyState extends State<_EloHistoryBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chronological = widget.entries.reversed.toList();
    final textTheme = Theme.of(context).textTheme;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    if (chronological.isEmpty) {
      return SizedBox(
        height: widget.chartHeight + 16,
        child: Center(
          child: Text(
            widget.fallbackElo != null
                ? 'No rated matches yet · ${widget.fallbackElo} ELO'
                : 'No rated matches yet',
            style: textTheme.bodyMedium?.copyWith(color: onSurfaceVariant),
          ),
        ),
      );
    }

    final latest = chronological.last;
    final trendUp = latest.delta >= 0;
    final trendColor = latest.delta == 0
        ? onSurfaceVariant
        : (trendUp ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C));

    return Column(
      crossAxisAlignment: .start,
      mainAxisSize: .min,
      children: [
        Row(
          crossAxisAlignment: .end,
          children: [
            Text(
              'ELO Trend',
              style: textTheme.titleSmall?.copyWith(fontWeight: .w600),
            ),
            const Spacer(),
            if (latest.delta != 0)
              Icon(
                trendUp
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                color: trendColor,
                size: 18,
              ),
            if (latest.delta != 0) const SizedBox(width: 4),
            Text(
              '${latest.delta > 0 ? '+' : ''}${latest.delta}',
              style: TextStyle(
                color: trendColor,
                fontWeight: .bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
        Text(
          '${latest.ratingAfter}',
          style: textTheme.headlineMedium?.copyWith(fontWeight: .w800),
        ),
        const SizedBox(height: 12),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => SizedBox(
            height: widget.chartHeight,
            width: double.infinity,
            child: CustomPaint(
              painter: _EloChartPainter(
                entries: chronological,
                progress: Curves.easeOutCubic.transform(_controller.value),
                lineColor: trendColor,
                gridColor: onSurfaceVariant.withAlpha(30),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EloChartPainter extends CustomPainter {
  _EloChartPainter({
    required this.entries,
    required this.progress,
    required this.lineColor,
    required this.gridColor,
  });

  final List<EloHistoryEntry> entries;
  final double progress;
  final Color lineColor;
  final Color gridColor;

  static const double _verticalPadding = 10;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final f in [0.0, 0.5, 1.0]) {
      final y = _verticalPadding + f * (size.height - _verticalPadding * 2);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (entries.length == 1) {
      canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        5,
        Paint()..color = lineColor,
      );
      return;
    }

    final ratings = entries.map((e) => e.ratingAfter.toDouble()).toList();
    final minR = ratings.reduce(math.min);
    final maxR = ratings.reduce(math.max);
    final span = (maxR - minR) < 1 ? 1.0 : (maxR - minR);

    Offset pointAt(int i) {
      final x = size.width * i / (entries.length - 1);
      final t = (ratings[i] - minR) / span;
      final y =
          _verticalPadding + (1 - t) * (size.height - _verticalPadding * 2);
      return Offset(x, y);
    }

    final points = List.generate(entries.length, pointAt);

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
      path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * progress, size.height));

    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: .topCenter,
        end: .bottomCenter,
        colors: [lineColor.withAlpha(70), lineColor.withAlpha(0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..color = lineColor.withAlpha(50)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(path, glowPaint);

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = lineColor;
    canvas.drawPath(path, linePaint);

    for (int i = 0; i < points.length; i++) {
      final isLast = i == points.length - 1;
      canvas.drawCircle(
        points[i],
        isLast ? 5.5 : 3,
        Paint()..color = lineColor,
      );
      if (isLast) {
        canvas.drawCircle(
          points[i],
          5.5,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _EloChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.entries != entries ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor;
  }
}
