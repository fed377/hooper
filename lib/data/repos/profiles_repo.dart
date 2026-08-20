import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/player_profile.dart';

abstract class PlayerProfileRepository {
  Stream<PlayerProfile> watchMyProfile(String uid);

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
  Future<int> myGlobalRank(int myElo);
  Future<void> updateLocation(String uid, GeoPoint location);
}
