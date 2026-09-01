import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hooper/features/discovery/data/matchup.dart';

class LeaderboardPage {
  final List<Matchup> entries;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;

  LeaderboardPage({required this.entries, required this.lastDocument, required this.hasMore});
}
