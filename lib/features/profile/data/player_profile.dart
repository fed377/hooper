import 'package:cloud_firestore/cloud_firestore.dart';

enum PlayerPosition { guard, forward, center }

PlayerPosition? playerPositionFromInt(int value) => switch (value) {
  1 => .guard,
  2 => .forward,
  3 => .center,
  int() => null,
};

int playerPositionToInt(PlayerPosition? position) {
  if (position == .guard) return 1;
  if (position == .forward) return 2;
  if (position == .center) return 3;
  return 0;
}

final _positions = ["Guard", "Forward", "Center"];

String playerPositionToString(PlayerPosition? position) =>
    _positions[playerPositionToInt(position)];

enum Gender { woman, man, other }

Gender? genderFromInt(int? value) => switch (value) {
  1 => .woman,
  2 => .man,
  3 => .other,
  _ => null,
};

int genderToInt(Gender? gender) {
  if (gender == .woman) return 1;
  if (gender == .man) return 2;
  if (gender == .other) return 3;
  return 0;
}

final _genders = ["Not set", "Woman", "Man", "Other"];

String genderToString(Gender? gender) => _genders[genderToInt(gender)];

class PlayerProfile {
  final String userId;
  final String displayName;
  final String? photoUrl;
  final String? bannerUrl;
  final int height;
  final int position;
  final String bio;
  final int elo;
  final int gamesPlayed1v1;
  final List<bool> recentForm;
  final List<String> lockedMatchIds;
  final List<String>? completedMatchIds;
  int visibilityRadius;
  final GeoPoint? homeLocation;
  final DateTime? lastActiveAt;
  final int? gender;

  PlayerPosition? get pos => playerPositionFromInt(position);
  Gender? get genderValue => genderFromInt(gender);

  PlayerProfile({
    required this.userId,
    required this.displayName,
    required this.photoUrl,
    required this.bannerUrl,
    required this.height,
    required this.position,
    required this.bio,
    required this.elo,
    required this.gamesPlayed1v1,
    this.recentForm = const [],
    required this.lockedMatchIds,
    required this.completedMatchIds,
    required this.visibilityRadius,
    this.homeLocation,
    this.lastActiveAt,
    this.gender,
  });

  factory PlayerProfile.fromJson(Map<String, dynamic> json) {
    return PlayerProfile(
      userId: json['userId'] as String,
      displayName: json['displayName'] as String,
      photoUrl: json['photoUrl'] as String?,
      bannerUrl: json['bannerUrl'] as String?,
      height: json['height'] as int,
      position: json['position'] as int,
      bio: json['bio'] as String,
      elo: json['elo'] as int,
      gamesPlayed1v1: json['gamesPlayed1v1'] as int,
      recentForm: (json['recentForm'] as List).cast<bool>(),
      lockedMatchIds:
          (json['lockedMatchIds'] as List?)?.cast<String>() ?? const [],
      completedMatchIds:
          (json['completedMatches'] as List?)?.cast<String>() ?? const [],
      visibilityRadius: json['visibilityRadius'] as int,
      homeLocation: json['homeLocation'] as GeoPoint?,
      lastActiveAt: (json['lastActive'] as Timestamp?)?.toDate(),
      gender: json['gender'] as int?,
    );
  }

  factory PlayerProfile.dummy() {
    return PlayerProfile(
      bannerUrl: '',
      userId: '',
      displayName: '',
      photoUrl: null,
      height: 184,
      position: 3,
      bio: '',
      elo: 1200,
      gamesPlayed1v1: 56,
      lockedMatchIds: [],
      completedMatchIds: [],
      visibilityRadius: 10,
    );
  }
}
