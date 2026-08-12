import 'package:cloud_firestore/cloud_firestore.dart';

enum PlayerPosition { guard, forward, center }

PlayerPosition? playerPositionFromInt(int value) {
  switch (value) {
    case 1:
      return PlayerPosition.guard;
    case 2:
      return PlayerPosition.forward;
    case 3:
      return PlayerPosition.center;
    default:
      return null;
  }
}

int playerPositionToInt(PlayerPosition? position) {
  if (position == PlayerPosition.guard) return 1;
  if (position == PlayerPosition.forward) return 2;
  if (position == PlayerPosition.center) return 3;
  return 0;
}

class PlayerProfile {
  final String userId;
  final String displayName;
  final String? photoUrl;
  final int height;
  final int position;
  final String bio;
  final int elo;
  final int gamesPlayed1v1;
  final List<bool> recentForm;
  final bool locked;
  final String? lockedMatchId;
  int visibilityRadius;
  final GeoPoint? homeLocation;
  final DateTime? lastActiveAt;

  PlayerPosition? get pos => playerPositionFromInt(position);

  PlayerProfile({
    required this.userId,
    required this.displayName,
    required this.photoUrl,
    required this.height,
    required this.position,
    required this.bio,
    required this.elo,
    required this.gamesPlayed1v1,
    this.recentForm = const [],
    required this.locked,
    this.lockedMatchId,
    required this.visibilityRadius,
    this.homeLocation,
    this.lastActiveAt,
  });

  factory PlayerProfile.fromJson(Map<String, dynamic> json) {
    return PlayerProfile(
      userId: json['userId'] as String,
      displayName: json['displayName'] as String,
      photoUrl: json['photoUrl'] as String?,
      height: json['height'] as int,
      position: json['position'] as int,
      bio: json['bio'] as String,
      elo: json['elo'] as int,
      gamesPlayed1v1: json['gamesPlayed1v1'] as int,
      recentForm: (json['recentForm'] as List).cast<bool>(),
      locked: json['isLocked'] as bool? ?? false,
      lockedMatchId: json['lockedMatchId'] as String?,
      visibilityRadius: json['visibilityRadius'] as int,
      homeLocation: json['homeLocation'] as GeoPoint?,
      lastActiveAt: (json['lastActive'] as Timestamp?)?.toDate(),
    );
  }
}
