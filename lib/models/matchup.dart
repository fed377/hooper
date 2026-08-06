import 'package:cloud_firestore/cloud_firestore.dart';

enum Tier { rookie, rising, baller, pro, elite }

Tier tierForElo(int elo) {
  if (elo >= 1900) return Tier.elite;
  if (elo >= 1600) return Tier.pro;
  if (elo >= 1300) return Tier.baller;
  if (elo >= 1000) return Tier.rising;
  return Tier.rookie;
}

String tierLabel(Tier tier) {
  switch (tier) {
    case Tier.rookie:
      return 'Rookie';
    case Tier.rising:
      return 'Rising';
    case Tier.baller:
      return 'Baller';
    case Tier.pro:
      return 'Pro';
    case Tier.elite:
      return 'Elite';
  }
}

class Matchup {
  final String id;
  final String displayName;
  final String? photoUrl;
  final int elo;
  final double distanceKm;
  final List<bool> recentForm;
  final bool isLocked;
  final DateTime lastActive;
  final int gamesPlayed1v1;
  final int visibilityRadius;
  final String? lockedMatchId;

  Matchup({
    required this.id,
    required this.displayName,
    required this.elo,
    required this.distanceKm,
    required this.recentForm,
    required this.gamesPlayed1v1,
    required this.photoUrl,
    required this.isLocked,
    required this.visibilityRadius,
    required this.lockedMatchId,
    DateTime? lastActive,
  }) : lastActive = lastActive ?? DateTime.now();

  Tier get tier => tierForElo(elo);

  factory Matchup.fromJson(Map<String, dynamic> data) {
    return Matchup(
      id: data['id'] as String,
      displayName: data['displayName'] as String,
      photoUrl: data['photoUrl'] as String?,
      elo: data['elo'] as int,
      distanceKm: (data['distanceKm'] as num).toDouble(),
      visibilityRadius: data['visibilityRadius'] as int,
      isLocked: data['isLocked'] as bool? ?? false,
      lockedMatchId: data['lockedMatchId'] as String?,
      recentForm: (data['recentForm'] as List).cast<bool>(),
      lastActive: DateTime.parse((data['lastActive'] as Timestamp).toDate().toIso8601String()),
      gamesPlayed1v1: data['gamesPlayed1v1'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    //TODO: fix tojson
    return {
      'displayName': displayName,
      'photoUrl': photoUrl,
      'elo': elo,
      'recentForm': recentForm,
      'isLocked': isLocked,
      'lastActive': lastActive.toIso8601String(),
      'gamesPlayed1v1': gamesPlayed1v1,
    };
  }
}
