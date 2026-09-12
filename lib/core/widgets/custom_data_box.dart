import 'package:flutter/material.dart';
import 'package:hooper/core/utils/utils.dart';
import 'package:hooper/core/widgets/blurred_container.dart';

class CustomDataBox extends StatefulWidget {
  const new({super.key, required this.value, required this.label, required this.icon, this.sigma = 0, this.color});

  final String value;
  final String label;
  final IconData icon;
  final double sigma;
  final Color? color;

  @override
  State<CustomDataBox> createState() => _CustomDataBoxState();
}

class _CustomDataBoxState extends State<CustomDataBox> {
  late Color currColor;

  @override
  void initState() {
    super.initState();
    currColor = widget.color ?? HooprColors.instance.blurColor;
  }

  @override
  Widget build(BuildContext context) {
    final text = TextTheme.of(context);
    return AspectRatio(
      aspectRatio: 1.3,
      child: BlurredContainer(
        elevation: 2, 
        color: currColor,
        sigma: widget.sigma,
        radius: 24,
        child: Padding(
          padding: const EdgeInsets.only(top: 12.0, left: 12, bottom: 12),
          child: Column(
            crossAxisAlignment: .start,
            children: [
              Row(
                children: [
                  Container(
                    padding: .all(10),
                    decoration: ShapeDecoration(
                      shape: RoundedSuperellipseBorder(borderRadius: .circular(50)),
                      color: Colors.white,
                    ),
                    child: Icon(widget.icon),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.label,
                    style: text.titleMedium?.copyWith(fontWeight: .w400),
                    overflow: .clip,
                  ),
                ],
              ),
              const Spacer(),
              Text(
                widget.value,
                style: text.headlineMedium?.copyWith(fontWeight: .w800, fontVariations: [FontVariation('ROND', 100)]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
