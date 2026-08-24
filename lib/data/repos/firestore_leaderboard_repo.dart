import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hooper/data/repos/leaderboard_repo.dart';

import '../../models/matchup.dart';

class FirestoreLeaderboardRepository implements LeaderboardRepository {
  FirestoreLeaderboardRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
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
}
