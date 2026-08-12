import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hooper/data/repos/firestore_matchups.dart';
import 'package:hooper/models/matchup.dart';

abstract class MatchupRepository {
  Stream<List<Matchup>> nearbyMatchups({
    required GeoPoint? center,
    required double radiusKm,
    required String excludeUserId,
  });
  Future<ProposalResponse> proposeMatch({
    required String court,
    required String targetId,
    required DateTime scheduledTime,
  });
}

class ProposeMatchException implements Exception {
  final String message;
  final String code;
  ProposeMatchException(this.code, this.message);

  @override
  String toString() => 'ProposeMatchException($code): $message';
}
