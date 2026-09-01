import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/matchup.dart';

class LeaderboardPage {
  final List<Matchup> entries;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;

  LeaderboardPage({required this.entries, required this.lastDocument, required this.hasMore});
}

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
}
