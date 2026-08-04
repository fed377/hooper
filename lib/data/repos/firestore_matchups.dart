// data/repositories/firestore_matchup_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:hooper/data/repos/matchup_repo.dart';
import 'package:hooper/models/matchup.dart';

class FirestoreMatchupRepository implements MatchupRepository {
  final _col = FirebaseFirestore.instance
      .collection('playerProfiles')
      .withConverter<Matchup>(
        fromFirestore: (snap, _) => Matchup.fromJson({...snap.data()!, 'id': snap.id}),
        toFirestore: (matchup, _) => matchup.toJson(),
      );

  FirestoreMatchupRepository({FirebaseFirestore? firestore, FirebaseFunctions? functions})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _functions = functions ?? FirebaseFunctions.instance;

  CollectionReference<Matchup> get _playerProfiles => _firestore
      .collection('playerProfiles')
      .withConverter<Matchup>(
        fromFirestore: (snap, _) => Matchup.fromJson({...snap.data()!, 'id': snap.id}),
        toFirestore: (matchup, _) => matchup.toJson(),
      );

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  @override
  Stream<List<Matchup>> nearbyMatchups({required GeoPoint center, required double radiusKm}) {
    // A real radius search needs a geohash range query (geoflutterfire2 is
    // the usual pick) built around `center`/`radiusKm`. This starter
    // version just excludes locked profiles so the shape of the pipeline
    // is in place — swap the query below once geo-bucketing is wired up.
    return _playerProfiles
        .where('isLocked', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data()).toList());
  }

  @override
  Future<String> proposeMatch({
    required String courtId,
    required String targetId,
    required DateTime scheduledTime,
  }) async {
    try {
      final result = await _functions.httpsCallable('proposeMatch').call({
        'targetId': targetId,
        'courtId': courtId,
        'scheduledTime': scheduledTime.toIso8601String(),
      });

      final data = Map<String, dynamic>.from(result.data as Map);
      return data['matchRequestId'] as String;
    } on FirebaseFunctionsException catch (e) {
      throw ProposeMatchException(e.code, e.message ?? 'Could not send challenge. Try again.');
    }
  }
}
