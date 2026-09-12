import 'package:flutter/material.dart';
import 'package:hooper/core/utils/utils.dart';
import 'package:hooper/core/widgets/blurred_container.dart';

class CustomDataBox extends StatelessWidget {
  const new({super.key, required this.value, required this.label, required this.icon, this.sigma = 0, this.color});

  final String value;
  final String label;
  final IconData icon;
  final double sigma;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final text = TextTheme.of(context);
    return AspectRatio(
      aspectRatio: 1.3,
      child: BlurredContainer(
        elevation: 1,
        sigma: sigma,
        radius: 24,
        color: color,
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
                      color: HooprColors.instance.glass ? Colors.white : HooprColors.instance.elevationColors[2],
                    ),
                    child: Icon(icon),
                  ),
                  const SizedBox(width: 8),
                  Text(label, style: text.titleMedium?.copyWith(fontWeight: .w400), overflow: .clip),
                ],
              ),
              const Spacer(),
              Text(
                value,
                style: text.headlineMedium?.copyWith(fontWeight: .w800, fontVariations: [FontVariation('ROND', 100)]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
