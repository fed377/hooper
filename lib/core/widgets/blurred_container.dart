import 'package:flutter/material.dart';
import 'package:hooper/core/utils/utils.dart';

class BlurredContainer extends StatelessWidget {
  const new({
    super.key,
    this._radius = 36.0,
    required this.child,
    this._sigma = 30,
    this._color,
    this.outline,
    this.height,
    this.borderWidth,
    required this.elevation,
  });

  final double _radius;
  final double _sigma;
  final Widget child;
  final double? height;
  final Color? _color;
  final bool? outline;
  final double? borderWidth;
  final int elevation;

  // Fixed constants, so these were pure waste to rebuild on every asHero()
  // call — hoisted to static and computed once.
  static final TweenSequence<double> _heightSequence = _buildSequence([
    1.0,
    1.1,
    1.0,
  ]);
  static final TweenSequence<double> _widthSequence = _buildSequence([
    1.0,
    0.95,
    1.0,
  ]);

  static TweenSequence<double> _buildSequence(List<double> values) {
    return TweenSequence<double>(
      List.generate(values.length - 1, (i) {
        final curr = values[i];
        final next = values[i + 1];
        return TweenSequenceItem(
          tween: Tween<double>(
            begin: curr,
            end: next,
          ).chain(CurveTween(curve: Curves.easeInOut)),
          weight: 1,
        );
      }),
    );
  }

  Widget asHero(String tag) {
    return Hero(
      curve: Curves.easeInOut,
      transitionOnUserGestures: true,
      tag: tag,
      flightShuttleBuilder:
          (
            flightContext,
            animation,
            flightDirection,
            fromHeroContext,
            toHeroContext,
          ) {
            final smallWidget =
                ((flightDirection == .push ? fromHeroContext : toHeroContext)
                                .widget
                            as Hero)
                        .child
                    as BlurredContainer;
            final bigWidget =
                ((flightDirection == .push ? toHeroContext : fromHeroContext)
                                .widget
                            as Hero)
                        .child
                    as BlurredContainer;
            return Material(
              type: .transparency,
              child: Stack(
                children: [
                  AnimatedBuilder(
                    animation: animation,
                    builder: (context, child) {
                      return Transform.scale(
                        scaleX: _widthSequence.evaluate(animation),
                        scaleY: _heightSequence.evaluate(animation),
                        child: BlurredContainer(
                          elevation: 1,
                          child: SingleChildScrollView(
                            child: Opacity(
                              opacity: animation.value,
                              child: bigWidget.child,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  AnimatedBuilder(
                    animation: animation,
                    builder: (context, child) {
                      return Transform.scale(
                        scaleX: _widthSequence.evaluate(animation),
                        scaleY: _heightSequence.evaluate(animation),
                        child: SingleChildScrollView(
                          child: Opacity(
                            opacity: 1 - animation.value,
                            child: smallWidget.child,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
      child: this,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = HooprTheme.instance;
    final glass = colors.glass;
    final shouldBorder = (outline ?? glass);
    // RepaintBoundary isolates the (expensive) BackdropFilter blur from
    // repainting whenever an unrelated ancestor/sibling repaints.
    Widget content = RepaintBoundary(
      child: ClipRSuperellipse(
        borderRadius: .circular(_radius),
        child: BackdropFilter(
          enabled: _sigma != 0 && glass,
          filterConfig: .blur(
            sigmaX: _sigma,
            sigmaY: _sigma,
            tileMode: .mirror,
          ),
          child: AnimatedContainer(
            duration: Durations.medium1,
            height: height,
            decoration: ShapeDecoration(
              color: glass
                  ? (_color ?? colors.blurColor)
                  : (_color ??
                        HooprTheme.instance.elevationColors[elevation - 1]),
              shape: RoundedSuperellipseBorder(
                borderRadius: .circular(_radius),
                side: !shouldBorder
                    ? .none
                    : .new(color: colors.borderColor, width: borderWidth ?? 1),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );

    if (!glass) {
      content = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_radius),
          boxShadow: [colors.blurredContainerShadow],
        ),
        child: content,
      );
    }

    return content;
  }
}
