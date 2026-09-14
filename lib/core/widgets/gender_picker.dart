import 'package:flutter/material.dart';
import 'package:hooper/features/profile/data/player_profile.dart';

import 'animated_blurred_picker.dart';

class GenderPicker extends StatefulWidget {
  const new({
    super.key,
    required this.enabled,
    required this.onSelectionChanged,
    required this.selected,
  });

  final bool enabled;
  final void Function(Gender) onSelectionChanged;
  final Gender? selected;

  @override
  State<GenderPicker> createState() => _GenderPickerState();
}

class _GenderPickerState extends State<GenderPicker> {
  @override
  Widget build(BuildContext context) {
    final radius = 22.0;
    final height = 50.0;
    final double currItem = (genderToInt(widget.selected) - 1)
        .clamp(0, 2)
        .toDouble();
    final elements = [Text("Woman"), Text("Man"), Text("Other")];
    void onTap(int p1) {
      widget.onSelectionChanged(genderFromInt(p1 + 1)!);
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
