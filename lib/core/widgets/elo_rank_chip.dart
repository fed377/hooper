import 'package:flutter/material.dart';
import 'package:hooper/features/discovery/data/matchup.dart';

class EloRankChip extends StatelessWidget {
  final int elo;
  const EloRankChip({super.key, required this.elo});

  (String, Color) _labelAndColor() => switch (tierForElo(elo)) {
    .rookie => ('Rookie', Colors.lightBlue),
    .rising => ('Rising', Colors.blueAccent),
    .baller => ('Baller', Colors.brown),
    .pro => ('Pro', Colors.blueGrey),
    .elite => ('Elite', Colors.amber),
  };

  @override
  Widget build(BuildContext context) {
    final (label, color) = _labelAndColor();
    final textColor = ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: .circular(8)),
      child: Text(label, style: TextStyle(color: textColor, fontSize: 11, fontWeight: .bold)),
    );
  }
}
