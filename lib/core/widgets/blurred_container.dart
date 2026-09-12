import 'package:flutter/material.dart';
import 'package:hooper/core/utils/utils.dart';

class BlurredContainer extends StatelessWidget {
  const new({
    super.key,
    this._radius = 36.0,
    required this.child,
    this._sigma = 30,
    this._color,
    this.outline = true,
    this.height,
    this.borderWidth,
    required this.elevation,
  });

  final double _radius;
  final double _sigma;
  final Widget child;
  final double? height;
  final Color? _color;
  final bool outline;
  final double? borderWidth;
  final int elevation;

  Widget asHero(String tag) {
    final scaleFactor = 0.5;
    final heightValues = <double>[1.0, 1 + .2 * scaleFactor, 1];
    final widthValues = <double>[1.0, 1 - .1 * scaleFactor, 1];

    final TweenSequence<double> heightSequence = TweenSequence<double>(
      List.generate(heightValues.length - 1, (i) {
        final index = i;
        final curr = heightValues[index];
        final next = heightValues[index + 1];
        return TweenSequenceItem(
          tween: Tween<double>(begin: curr, end: next).chain(CurveTween(curve: Curves.easeInOut)),
          weight: 1,
        );
      }),
    );

    final TweenSequence<double> widthSequence = TweenSequence<double>(
      List.generate(widthValues.length - 1, (i) {
        final index = i;
        final curr = widthValues[index];
        final next = widthValues[index + 1];
        return TweenSequenceItem(
          tween: Tween<double>(begin: curr, end: next).chain(CurveTween(curve: Curves.easeInOut)),
          weight: 1,
        );
      }),
    );

    return Hero(
      curve: Curves.easeInOut,
      transitionOnUserGestures: true,
      tag: tag,
      flightShuttleBuilder: (flightContext, animation, flightDirection, fromHeroContext, toHeroContext) {
        final smallWidget =
            ((flightDirection == .push ? fromHeroContext : toHeroContext).widget as Hero).child as BlurredContainer;
        final bigWidget =
            ((flightDirection == .push ? toHeroContext : fromHeroContext).widget as Hero).child as BlurredContainer;
        return Material(
          type: .transparency,
          child: Stack(
            children: [
              AnimatedBuilder(
                animation: animation,
                builder: (context, child) {
                  return Transform.scale(
                    scaleX: widthSequence.evaluate(animation),
                    scaleY: heightSequence.evaluate(animation),
                    child: BlurredContainer(
                      elevation: 1,
                      child: SingleChildScrollView(
                        child: Opacity(opacity: animation.value, child: bigWidget.child),
                      ),
                    ),
                  );
                },
              ),
              AnimatedBuilder(
                animation: animation,
                builder: (context, child) {
                  return Transform.scale(
                    scaleX: widthSequence.evaluate(animation),
                    scaleY: heightSequence.evaluate(animation),
                    child: SingleChildScrollView(
                      child: Opacity(opacity: 1 - animation.value, child: smallWidget.child),
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
    final colors = HooprColors.instance;
    return ClipRSuperellipse(
      borderRadius: .circular(_radius),
      child: BackdropFilter(
        enabled: _sigma != 0 && !HooprColors.instance.glass,
        filterConfig: .blur(sigmaX: _sigma, sigmaY: _sigma, tileMode: .mirror),
        child: AnimatedContainer(
          duration: Durations.medium1,
          height: height,
          decoration: ShapeDecoration(
            color: HooprColors.instance.glass
                ? (_color ?? colors.blurColor)
                : (_color ?? HooprColors.instance.elevationColors[elevation]),
            shape: RoundedSuperellipseBorder(
              borderRadius: .circular(_radius),
              side: !outline ? .none : .new(color: colors.borderColor, width: borderWidth ?? 1),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
