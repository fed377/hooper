import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hooper/features/location/data/geohash.dart';

import 'player_profile.dart';

class FirestorePlayerProfileRepository {
  FirestorePlayerProfileRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<PlayerProfile> watchMyProfile(String uid) {
    return _firestore.collection('playerProfiles').doc(uid).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) {
        throw StateError('playerProfiles/$uid does not exist yet.');
      }
      return PlayerProfile.fromJson({'userId': uid, ...data});
    });
  }

  Future<int> myGlobalRank(int myElo) async {
    final higher = await FirebaseFirestore.instance
        .collection('playerProfiles')
        .where('elo', isGreaterThan: myElo)
        .count()
        .get();
    return (higher.count ?? 0) + 1;
  }

  Future<void> updateEditableFields({
    required String uid,
    required String oldName,
    String? photoUrl,
    int? heightCm,
    PlayerPosition? position,
    String? bio,
    int? visibilityRadiusKm,
    String? displayName,
  }) async {
    final updates = <String, dynamic>{};
    if (photoUrl != null) updates['photoUrl'] = photoUrl;
    if (heightCm != null) updates['height'] = heightCm;
    if (position != null) updates['position'] = playerPositionToInt(position);
    if (bio != null) updates['bio'] = bio;
    if (visibilityRadiusKm != null) updates['visibilityRadius'] = visibilityRadiusKm;
    if (displayName != null) updates['displayName'] = displayName;

    if (updates.isEmpty) return;
    await _firestore.collection('playerProfiles').doc(uid).update(updates);
    if (displayName != oldName) {
      await _firestore.collection('usernames').doc(updates['displayName']).set({'uid': uid});
      await _firestore.collection('usernames').doc(oldName).delete();
    }
  }

  Future<void> touchLastActive(String uid) {
    return _firestore.collection('playerProfiles').doc(uid).update({'lastActive': FieldValue.serverTimestamp()});
  }

  Future<void> updateLocation(String uid, GeoPoint location) {
    final hash = geohashEncode(location.latitude, location.longitude, precision: 9);
    return _firestore.collection('playerProfiles').doc(uid).update({'homeLocation': location, 'geohash': hash});
  }
}
