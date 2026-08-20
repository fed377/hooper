import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:hooper/models/user_preference.dart';

//Report Status: Sent, Reviewing, Finished

class FirestorePreferencesRepository {
  FirestorePreferencesRepository({FirebaseFirestore? firestore, FirebaseFunctions? functions})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<UserPreference> watchMyPreferences(String uid) {
    return _firestore.collection('userPreferences').doc(uid).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) {
        throw StateError('playerProfiles/$uid does not exist yet.');
      }
      return UserPreference.fromJson({'userId': uid, ...data});
    });
  }

  Future<void> reportUser(String myId, String targetId, String reason, String? matchId) async {
    await _firestore.collection('reports').doc().set({
      'senderId': myId,
      'targetId': targetId,
      'reason': reason,
      'matchId': matchId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> blockUser(String myId, String targetId) async {
    await _firestore.collection('preferences').doc(myId).update({
      'blockedUsers': FieldValue.arrayUnion([targetId]),
    });
  }
}
