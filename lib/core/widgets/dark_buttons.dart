import 'package:flutter/material.dart';

class DarkFilledButton extends StatelessWidget {
  final Widget child;
  final void Function()? onPressed;
  final bool shadow;
  const new({super.key, required this.child, required this.onPressed, this.shadow = true});

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        padding: EdgeInsets.only(top: 16, bottom: 16, right: 24, left: 24),
        shape: RoundedSuperellipseBorder(borderRadius: .circular(50)),
        backgroundColor: const Color.fromARGB(223, 0, 0, 0),
        foregroundColor: Colors.white,
        backgroundBuilder: (context, states, child) {
          return Container(
            decoration: ShapeDecoration(
              shape: RoundedSuperellipseBorder(borderRadius: .circular(50)),
              color: Colors.black,
              shadows: shadow
                  ? [BoxShadow(color: const Color.fromARGB(94, 0, 0, 0), spreadRadius: -1, blurRadius: 20)]
                  : [],
            ),
            child: child,
          );
        },
      ),
      child: child,
    );
  }
}

class DarkIconButton extends StatelessWidget {
  final Widget icon;
  final void Function()? onPressed;
  final bool shadow;
  const new({super.key, required this.icon, required this.onPressed, this.shadow = true});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        padding: .all(12),
        shape: CircleBorder(),
        backgroundColor: const Color.fromARGB(223, 0, 0, 0),
        foregroundColor: Colors.white,
        backgroundBuilder: (context, states, child) {
          return Container(
            decoration: ShapeDecoration(
              shape: RoundedSuperellipseBorder(borderRadius: .circular(50)),
              color: Colors.black,
              shadows: shadow
                  ? [BoxShadow(color: const Color.fromARGB(94, 0, 0, 0), spreadRadius: -1, blurRadius: 20)]
                  : [],
            ),
            child: child,
          );
        },
      ),
      icon: icon,
    );
  }
}
