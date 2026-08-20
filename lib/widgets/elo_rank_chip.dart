import 'package:flutter/material.dart';
import 'package:hooper/models/matchup.dart';

class EloRankChip extends StatelessWidget {
  final int elo;
  const EloRankChip({super.key, required this.elo});

  (String, Color?) _labelAndColor(BuildContext context) {
    switch (tierForElo(elo)) {
      case Tier.rookie:
        return ('Rookie', Colors.lightBlue);
      case Tier.rising:
        return ('Rising', Colors.blueAccent);
      case Tier.baller:
        return ('Baller', Colors.brown);
      case Tier.pro:
        return ('Pro', Colors.grey);
      case Tier.elite:
        return ('Elite', Colors.amber);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (label, color) = _labelAndColor(context);
    return Chip(
      label: Text(label),
      labelStyle: color != null ? TextStyle(color: color) : null,
      visualDensity: VisualDensity.compact,
    );
  }
}
