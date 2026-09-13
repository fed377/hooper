import 'package:flutter/material.dart';
import 'package:hooper/core/utils/utils.dart';
import 'package:hooper/core/widgets/blurred_container.dart';

class BlurredPicker extends StatelessWidget {
  const new({
    super.key,
    required this.radius,
    required this.height,
    required this.progress,
    required this.elements,
    required this.onTap,
    this.elevation = 1,
    this.includeBlurredContainer = true,
    this.duration = Durations.medium3,
    this.sigma = 30,
    this.stretchFactor = 1,
    this.startIndex,
    this.endIndex,
  });

  final double radius;
  final double height;
  final double sigma;
  final int elevation;
  final double progress;
  final double? startIndex;
  final double? endIndex;
  final List<Widget> elements;
  final Duration duration;
  final double stretchFactor;
  final void Function(int) onTap;
  final bool includeBlurredContainer;

  // Static: these don't depend on any instance state, so building a fresh
  // TweenSequence (and its Tween/CurveTween tree) on every rebuild — this
  // widget rebuilds on every scroll frame via the bottom nav — was wasted work.
  static final TweenSequence<double> _heightTweenSequence = TweenSequence<double>([
    TweenSequenceItem(tween: Tween<double>(begin: 1, end: 0.9).chain(CurveTween(curve: Curves.easeInOut)), weight: 1),
    TweenSequenceItem(tween: Tween<double>(begin: 0.9, end: 1).chain(CurveTween(curve: Curves.easeInOut)), weight: 1),
  ]);
  static final TweenSequence<double> _widthTweenSequence = TweenSequence<double>([
    TweenSequenceItem(tween: Tween<double>(begin: 1, end: 1.2).chain(CurveTween(curve: Curves.easeInOut)), weight: 1),
    TweenSequenceItem(tween: Tween<double>(begin: 1.2, end: 1).chain(CurveTween(curve: Curves.easeInOut)), weight: 1),
  ]);

  @override
  Widget build(BuildContext context) {
    final colors = HooprTheme.instance;
    late double prog;
    if (startIndex != null) {
      final dist = endIndex! - startIndex!;
      prog = (progress - startIndex!) / dist;
    } else {
      prog = progress.remainder(1);
    }
    var widg = SizedBox(
      child: Stack(
        alignment: Alignment.center,
        children: [
          RepaintBoundary(
            child: Align(
              alignment: FractionalOffset((progress) / (elements.length - 1), 0),
              child: FractionallySizedBox(
                widthFactor: (1 / elements.length),
                heightFactor: 1,
                child: OverflowBox(
                  fit: .deferToChild,
                  child: Center(
                    child: FractionallySizedBox(
                      heightFactor: 1 - (1 - _heightTweenSequence.transform(prog)) * stretchFactor,
                      widthFactor: (1 - _widthTweenSequence.transform(prog)).abs() * stretchFactor + 1,
                      child: Container(
                        decoration: ShapeDecoration(
                          color: colors.darkenColor,
                          shape: RoundedSuperellipseBorder(borderRadius: .circular(radius - 8)),
                          shadows: colors.glass ? [] : [colors.pickerShadow],
                        ),
                        margin: EdgeInsets.all(8),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          RepaintBoundary(
            child: Row(
              crossAxisAlignment: .stretch,
              children: List.generate(elements.length, (index) {
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(index),
                    child: Center(child: elements[index]),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
    if (includeBlurredContainer) {
      return BlurredContainer(elevation: elevation, sigma: sigma, radius: radius, height: height, child: widg);
    } else {
      return SizedBox(height: height, child: widg);
    }
  }
}
