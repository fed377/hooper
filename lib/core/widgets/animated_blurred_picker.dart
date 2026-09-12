import 'package:flutter/material.dart';
import 'package:hooper/core/widgets/blurred_picker.dart';

class AnimatedBlurredPicker extends StatefulWidget {
  const new({
    super.key,
    required this.radius,
    required this.height,
    required this.currItem,
    required this.elements,
    required this.onTap,
    this.includeBlurredContainer = true,
    this.stretchFactor = 1,
    this.duration = Durations.short4,
  });

  final double radius;
  final double height;
  final double currItem;
  final double stretchFactor;
  final Duration duration;
  final List<Widget> elements;
  final bool includeBlurredContainer;
  final void Function(int p1) onTap;

  @override
  State<AnimatedBlurredPicker> createState() => _AnimatedBlurredPickerState();
}

class _AnimatedBlurredPickerState extends State<AnimatedBlurredPicker> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  int _targetValue = 1;
  double _currentValue = 1.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    _animation = Tween<double>(
      begin: 1.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));
  }

  void _onButtonPressed(int newValue) {
    if (newValue == _targetValue) return;

    setState(() {
      _animation = Tween<double>(
        begin: _currentValue,
        end: newValue.toDouble(),
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));

      _targetValue = newValue;
    });

    _controller.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,

      builder: (context, child) {
        _currentValue = _animation.value;
        return BlurredPicker(
          includeBlurredContainer: widget.includeBlurredContainer,
          radius: widget.radius,
          height: widget.height,
          progress: _currentValue,
          elements: widget.elements,
          duration: widget.duration,
          stretchFactor: widget.stretchFactor,
          onTap: (i) {
            _onButtonPressed(i);
            widget.onTap(i);
          },
        );
      },
    );
  }
}
