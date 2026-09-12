import 'package:cloud_firestore/cloud_firestore.dart';

import '../../discovery/data/matchup.dart';
import 'leaderboard_page.dart';

class FirestoreLeaderboardRepository {
  FirestoreLeaderboardRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<LeaderboardPage> fetchPage({DocumentSnapshot? startAfter, int pageSize = 20}) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('playerProfiles')
        .orderBy('elo', descending: true)
        .limit(pageSize);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snap = await query.get();

    final entries = snap.docs.map((d) => Matchup.fromJson({...d.data(), 'id': d.id, 'distanceKm': 10})).toList();

    return LeaderboardPage(
      entries: entries,
      lastDocument: snap.docs.isNotEmpty ? snap.docs.last : null,
      hasMore: snap.docs.length == pageSize,
    );
  }

  Future<LeaderboardPage> fetchAroundMe({required int myElo, int windowSize = 20}) async {
    final halfWindow = (windowSize / 2).ceil();

    final aboveSnap = await _firestore
        .collection('playerProfiles')
        .where('elo', isGreaterThan: myElo)
        .orderBy('elo')
        .limit(halfWindow)
        .get();

    final remaining = windowSize - aboveSnap.docs.length;
    final belowOrEqualSnap = await _firestore
        .collection('playerProfiles')
        .where('elo', isLessThanOrEqualTo: myElo)
        .orderBy('elo', descending: true)
        .limit(remaining > 0 ? remaining : 1)
        .get();

    final docs = [...aboveSnap.docs.reversed, ...belowOrEqualSnap.docs];
    if (docs.isEmpty) {
      return LeaderboardPage(entries: [], lastDocument: null, hasMore: false);
    }

    final topElo = docs.first.data()['elo'] as int;
    final aboveCount = await _firestore.collection('playerProfiles').where('elo', isGreaterThan: topElo).count().get();
    final startRank = (aboveCount.count ?? 0) + 1;

    final entries = docs.map((d) => Matchup.fromJson({...d.data(), 'id': d.id, 'distanceKm': 10})).toList();

    return LeaderboardPage(entries: entries, lastDocument: null, hasMore: false, startRank: startRank);
  }
}
