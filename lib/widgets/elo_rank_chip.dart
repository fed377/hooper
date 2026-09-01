import 'package:flutter/material.dart';
import 'package:hooper/models/matchup.dart';

class EloRankChip extends StatelessWidget {
  final int elo;
  const EloRankChip({super.key, required this.elo});

  (String, Color?) _labelAndColor(BuildContext context) => switch (tierForElo(elo)) {
    .rookie => ('Rookie', Colors.lightBlue),
    .rising => ('Rising', Colors.blueAccent),
    .baller => ('Baller', Colors.brown),
    .pro => ('Pro', Colors.grey),
    .elite => ('Elite', Colors.amber),
  };

  @override
  Widget build(BuildContext context) {
    final (label, color) = _labelAndColor(context);
    return Chip(
      shape: RoundedSuperellipseBorder(borderRadius: .circular(12)),
      label: Text(label),
      labelStyle: color != null ? TextStyle(color: color) : null,
      visualDensity: VisualDensity.compact,
    );
  }
}
