import 'dart:math' as math;

import 'package:flutter/material.dart';

class StretchBoxController {
  double left = 0;
  double right = 0;
  double top = 0;
  double bottom = 0;
  double width = 0;
  double height = 0;
  double constHeight = 0;
  double constWidth = 0;
  BorderRadius? borderRadius;
  double leftPad = 0;
  double rightPad = 0;
  double topPad = 0;
  double bottomPad = 0;

  double borderWidth = 0;

  late void Function(double) animateHeight;
  late void Function(double) animateWidth;
}

class StretchBoxClipper extends CustomClipper<Path> {
  final StretchBoxController delegate;

  StretchBoxClipper({super.reclip, required this.delegate});

  @override
  Path getClip(Size size) {
    return Path()..addRRect(
      (delegate.borderRadius ?? BorderRadius.zero).toRRect(
        Rect.fromLTWH(
          delegate.leftPad + delegate.left,
          delegate.topPad + delegate.top,
          delegate.width + delegate.borderWidth * 2,
          delegate.height + delegate.borderWidth * 2,
        ),
      ),
    );
  }

  @override
  bool shouldReclip(covariant StretchBoxClipper oldClipper) {
    return true;
  }
}

class StretchBox extends StatefulWidget {
  const StretchBox({
    super.key,
    this.height = 50,
    this.width = 50,
    this.xResistance = 10,
    this.yResistance = 10,
    this.xMoveResistance = 10,
    this.yMoveResistance = 1,
    this.padding,
    this.decoration,
    this.child,
    this.delegate,
    this.curve = Curves.fastOutSlowIn,
    this.sizeCurve = Curves.fastOutSlowIn,
    this.duration = Durations.short3,
    this.sizeDuration = Durations.long1,
  });
  final double height;
  final double width;
  final double xResistance;
  final double yResistance;
  final double xMoveResistance;
  final double yMoveResistance;
  final EdgeInsets? padding;
  final BoxDecoration? decoration;
  final Widget? child;
  final StretchBoxController? delegate;
  final Curve curve;
  final Curve sizeCurve;
  final Duration duration;
  final Duration sizeDuration;

  @override
  State<StretchBox> createState() => _StretchBoxState();
}

class _StretchBoxState extends State<StretchBox> with TickerProviderStateMixin {
  late AnimationController _controllerX;
  late Animation<double> _animationX;

  late AnimationController _controllerY;
  late Animation<double> _animationY;

  late AnimationController _controllerH;
  late Animation<double> _animationH;

  late AnimationController _controllerW;
  late Animation<double> _animationW;

  late double height;
  late double width;

  @override
  void initState() {
    super.initState();
    _controllerX = AnimationController(vsync: this, duration: widget.duration);
    _controllerY = AnimationController(vsync: this, duration: widget.duration);
    _controllerW = AnimationController(vsync: this, duration: widget.sizeDuration);
    _controllerH = AnimationController(vsync: this, duration: widget.sizeDuration);
    height = widget.height;
    width = widget.width;
    widget.delegate?.borderRadius = widget.decoration!.borderRadius?.resolve(TextDirection.ltr);
    widget.delegate?.animateHeight = animateHeightTo;
    widget.delegate?.animateWidth = animateWidthTo;
    widget.delegate?.constHeight = height;
    widget.delegate?.constWidth = width;
    widget.delegate?.bottomPad = widget.padding?.bottom ?? 0;
    widget.delegate?.topPad = widget.padding?.top ?? 0;
    widget.delegate?.rightPad = widget.padding?.right ?? 0;
    widget.delegate?.leftPad = widget.padding?.left ?? 0;
    assert((widget.decoration?.border?.isUniform) ?? true, 'Border must be uniform');
  }

  double growthFunc(double max, double val, {double rate = 0.001}) => max * (1 - math.exp(-(val.abs()) * rate));

  double get _realdy => growthFunc(40, _exitdy, rate: widget.yResistance / 1000);
  double get _exitdy => (_dy < 0 ? (_dy.abs() < _topY ? 0 : _dy + _topY) : (_dy < _bottomY ? 0 : _dy - _bottomY));

  double _dy = 0;
  double _bottomY = 0;
  double _topY = 0;

  void animateHeightTo(double h) {
    widget.delegate?.constHeight = h;
    _animationH = Tween(begin: height, end: h).animate(CurvedAnimation(parent: _controllerH, curve: widget.sizeCurve))
      ..addListener(() {
        setState(() {
          height = _animationH.value;
        });
      });

    _controllerH.forward(from: 0);
  }

  void animateWidthTo(double w) {
    widget.delegate?.constWidth = w;
    _animationW = Tween(begin: width, end: w).animate(CurvedAnimation(parent: _controllerW, curve: widget.sizeCurve))
      ..addListener(() {
        setState(() {
          width = _animationW.value;
        });
      });

    _controllerW.forward(from: 0);
  }

  void smoothResetY() {
    _animationY = Tween(begin: _dy, end: 0.0).animate(CurvedAnimation(parent: _controllerY, curve: widget.curve))
      ..addListener(() {
        setState(() {
          _dy = _animationY.value;
        });
      });

    _controllerY.forward(from: 0);
  }

  double get _realdx => growthFunc(40, _exitdx, rate: widget.xResistance / 1000);
  double get _exitdx => (_dx < 0 ? (_dx.abs() < _leftX ? 0 : _dx + _leftX) : (_dx < _rightX ? 0 : _dx - _rightX));

  double _dx = 0;
  double _rightX = 0;
  double _leftX = 0;

  void smoothResetX() {
    _animationX = Tween(begin: _dx, end: 0.0).animate(CurvedAnimation(parent: _controllerX, curve: widget.curve))
      ..addListener(() {
        setState(() {
          _dx = _animationX.value;
        });
      });

    _controllerX.forward(from: 0);
  }

  void disposeB() {
    smoothResetX();
    smoothResetY();
  }

  void bEnd(DragEndDetails d) {
    disposeB();
  }

  void bStart(DragStartDetails d) {
    setState(() {
      _rightX = width - d.localPosition.dx;
      _leftX = d.localPosition.dx;
      _topY = d.localPosition.dy;
      _bottomY = height - _topY;
    });
  }

  void bUpdate(DragUpdateDetails d) {
    setState(() => _dx += d.delta.dx);
    setState(() => _dy += d.delta.dy);
  }

  @override
  Widget build(BuildContext context) {
    double left = _exitdx < 0 ? 0 : (_realdx + growthFunc(50, _exitdx, rate: widget.xMoveResistance / 1000));
    double top = _exitdy < 0 ? 0 : (_realdy + growthFunc(50, _exitdy, rate: widget.yMoveResistance / 1000));
    double right = _exitdx > 0 ? 0 : (_realdx + growthFunc(50, _exitdx, rate: widget.xMoveResistance / 1000));
    double bottom = _exitdy > 0 ? 0 : (_realdy + growthFunc(50, _exitdy, rate: widget.yMoveResistance / 1000));

    var height2 = height - (growthFunc(height * 0.2, _dx, rate: widget.xResistance / 1000)) + _realdy;
    var width2 = width - (growthFunc(width * 0.2, _dy, rate: widget.yResistance / 1000)) + _realdx;
    widget.delegate
      ?..bottom = bottom
      ..top = top
      ..left = left
      ..right = right
      ..height = height2
      ..width = width2
      ..borderWidth = widget.decoration?.border?.top.width ?? 0
      ..borderRadius = widget.decoration?.borderRadius?.resolve(TextDirection.ltr);

    return GestureDetector(
      onPanCancel: disposeB,
      onPanEnd: bEnd,
      onPanStart: bStart,
      onPanUpdate: bUpdate,
      child: AnimatedContainer(
        margin: (widget.padding ?? EdgeInsets.zero),
        duration: widget.duration,
        decoration: widget.decoration ?? BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: EdgeInsets.fromLTRB(left, top, right, bottom),
          child: SizedBox(height: height2, width: width2, child: widget.child),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controllerX.dispose();
    _controllerY.dispose();
    _controllerW.dispose();
    _controllerH.dispose();
    super.dispose();
  }
}
