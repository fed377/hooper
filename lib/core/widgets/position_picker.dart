import 'package:flutter/material.dart';
import 'package:hooper/features/profile/data/player_profile.dart';

import 'animated_blurred_picker.dart';

class PositionPicker extends StatefulWidget {
  const new({super.key, required this.enabled, required this.onSelectionChanged, required this.selected});

  final bool enabled;
  final void Function(PlayerPosition) onSelectionChanged;
  final PlayerPosition selected;

  @override
  State<PositionPicker> createState() => _PositionPickerState();
}

class _PositionPickerState extends State<PositionPicker> {
  @override
  Widget build(BuildContext context) {
    final radius = 22.0;
    final height = 50.0;
    final double currItem = playerPositionToInt(widget.selected) - 1;
    final elements = [Text("Guard"), Text("Forward"), Text("Center")];
    void onTap(int p1) {
      widget.onSelectionChanged(playerPositionFromInt(p1 + 1)!);
    }

    return AnimatedBlurredPicker(
      radius: radius,
      height: height,
      currItem: currItem,
      elements: elements,
      onTap: onTap,
      stretchFactor: 0.8,
    );
  }
}
