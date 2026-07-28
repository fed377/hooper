// data/repositories/firestore_matchup_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hooper/data/firestore_paths.dart';
import 'package:hooper/data/repos/matchup_repo.dart';
import 'package:hooper/models/matchup.dart';

class FirestoreMatchupRepository implements MatchupRepository {
  final _col = FirebaseFirestore.instance
      .collection(PLAYER_PROFILES)
      .withConverter<Matchup>(
        fromFirestore: (snap, _) => Matchup.fromJson({...snap.data()!, 'id': snap.id}),
        toFirestore: (matchup, _) => matchup.toJson(),
      );

  @override
  Stream<List<Matchup>> nearbyMatchups({required GeoPoint center, required double radiusKm}) {
    // geohash-range query here (geoflutterfire2 is the usual pick)
    return _col.where('isLocked', isEqualTo: false).snapshots()
        .map((snap) => snap.docs.map((d) => d.data()).toList());
  }
  
  @override
  Future<void> proposeMatch(String targetId, String courtId, DateTime time) {
    // TODO: implement proposeMatch
    throw UnimplementedError();
  }
}