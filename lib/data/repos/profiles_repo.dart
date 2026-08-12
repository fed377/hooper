import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/player_profile.dart';

/// Scoped entirely to the CURRENT user's own profile — never used to
/// look at someone else's. Discovery of other players stays on
/// MatchupRepository, which returns the separate, stripped-down
/// Matchup view instead.
abstract class PlayerProfileRepository {
  Stream<PlayerProfile> watchMyProfile(String uid);

  /// Only touches fields a player is allowed to self-edit. elo,
  /// isLocked, lockedMatchId, and gamesPlayed1v1 are never accepted
  /// here — those stay exclusively under Cloud Functions control
  /// (reconcileScore, acceptRequest). Only non-null params are written.
  Future<void> updateEditableFields({
    required String uid,
    required String oldName,
    String? photoUrl,
    int? heightCm,
    PlayerPosition? position,
    String? bio,
    int? visibilityRadiusKm,
    String? displayName,
  });

  Future<void> touchLastActive(String uid);

  Future<void> updateLocation(String uid, GeoPoint location);
}
