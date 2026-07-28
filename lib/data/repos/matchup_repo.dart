import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hooper/models/matchup.dart';

abstract class MatchupRepository {
  Stream<List<Matchup>> nearbyMatchups({required GeoPoint center, required double radiusKm});
  Future<void> proposeMatch(String targetId, String courtId, DateTime time);
}

class ProposeMatchException implements Exception {
  final String message;
  final String code;
  ProposeMatchException(this.code, this.message);

  @override
  String toString() => 'ProposeMatchException($code): $message';
}
