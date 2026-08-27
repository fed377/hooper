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
  final String? bannerUrl;
  final int elo;
  final double distanceKm;
  final List<bool> recentForm;
  final DateTime lastActive;
  final int gamesPlayed1v1;
  final int visibilityRadius;
  final String? bio;
  final int height;
  final int position;

  Matchup({
    required this.id,
    required this.displayName,
    required this.elo,
    required this.distanceKm,
    required this.recentForm,
    required this.gamesPlayed1v1,
    required this.photoUrl,
    required this.bannerUrl,
    required this.visibilityRadius,
    required this.bio,
    required this.height,
    required this.position,
    DateTime? lastActive,
  }) : lastActive = lastActive ?? DateTime.now();

  Tier get tier => tierForElo(elo);

  factory Matchup.fromJson(Map<String, dynamic> data) {
    return Matchup(
      id: data['id'] as String,
      displayName: data['displayName'] as String,
      photoUrl: data['photoUrl'] as String?,
      bannerUrl: data['bannerUrl'] as String?,
      elo: data['elo'] as int,
      distanceKm: (data['distanceKm'] as num).toDouble(),
      visibilityRadius: data['visibilityRadius'] as int,
      recentForm: (data['recentForm'] as List).cast<bool>(),
      lastActive: DateTime.parse((data['lastActive'] as Timestamp).toDate().toIso8601String()),
      gamesPlayed1v1: data['gamesPlayed1v1'] as int,
      bio: data['bio'] as String?,
      height: data['height'] as int,
      position: data['position'] as int,
    );
  }

  factory Matchup.dummy() {
    return Matchup(
      id: '',
      displayName: 'dummy',
      elo: 1200,
      distanceKm: 10.5,
      recentForm: [true, false, false, false, true],
      gamesPlayed1v1: 74,
      photoUrl: null,
      bannerUrl: '',
      visibilityRadius: 10,
      bio: '',
      height: 184,
      position: 3,
    );
  }

  //not used for anything
  Map<String, dynamic> toJson() => {};
}
