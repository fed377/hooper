import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../models/match.dart';
import 'match_repo.dart';

class FirestoreMatchRepository implements MatchRepository {
  FirestoreMatchRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  @override
  Stream<MatchDoc> watchMatch(String matchId) {
    return _firestore.collection('matches').doc(matchId).snapshots().map((snap) {
      final data = snap.data()!;
      return MatchDoc.fromJson({
        ...data,
        'id': snap.id,
        // Firestore Timestamp -> DateTime; fromJson expects a DateTime.
        'scheduledTime': (data['scheduledTime'] as Timestamp).toDate(),
      });
    });
  }

  @override
  Stream<List<IncomingRequest>> watchIncomingRequests(String uid) {
    return _firestore
        .collection('matchRequests')
        .where('targetId', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final data = d.data();
              return IncomingRequest.fromJson({
                ...data,
                'id': d.id,
                'scheduledTime': (data['scheduledTime'] as Timestamp).toDate(),
              });
            }).toList());
  }

  @override
  Stream<String?> watchMyLockedMatchId(String uid) {
    return _firestore
        .collection('playerProfiles')
        .doc(uid)
        .snapshots()
        .map((snap) => snap.data()?['lockedMatchId'] as String?);
  }

  @override
  Future<String> acceptRequest(String matchRequestId) async {
    try {
      final result = await _functions
          .httpsCallable('acceptRequest')
          .call({'matchRequestId': matchRequestId});
      final data = Map<String, dynamic>.from(result.data as Map);
      return data['matchId'] as String;
    } on FirebaseFunctionsException catch (e) {
      throw MatchActionException(e.code, e.message ?? 'Could not accept.');
    }
  }

  @override
  Future<void> declineRequest(String matchRequestId) async {
    try {
      await _functions
          .httpsCallable('declineRequest')
          .call({'matchRequestId': matchRequestId});
    } on FirebaseFunctionsException catch (e) {
      throw MatchActionException(e.code, e.message ?? 'Could not decline.');
    }
  }

  @override
  Future<void> cancelMatch(String matchId) async {
    try {
      await _functions.httpsCallable('cancelMatch').call({'matchId': matchId});
    } on FirebaseFunctionsException catch (e) {
      throw MatchActionException(e.code, e.message ?? 'Could not cancel.');
    }
  }

  @override
  Future<void> submitScore({
    required String matchId,
    required int myScore,
    required int opponentScore,
  }) async {
    try {
      await _functions.httpsCallable('submitScore').call({
        'matchId': matchId,
        'myScore': myScore,
        'opponentScore': opponentScore,
      });
    } on FirebaseFunctionsException catch (e) {
      throw MatchActionException(e.code, e.message ?? 'Could not submit score.');
    }
  }
}