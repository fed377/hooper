import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/matchup.dart';

class LeaderboardPage {
  final List<Matchup> entries;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;

  LeaderboardPage({required this.entries, required this.lastDocument, required this.hasMore});
}

abstract class LeaderboardRepository {
  Future<LeaderboardPage> fetchPage({DocumentSnapshot? startAfter, int pageSize = 20});
}
