import 'package:cloud_firestore/cloud_firestore.dart';

class EloHistoryEntry {
  final String matchId;
  final int ratingBefore;
  final int ratingAfter;
  final int delta;
  final DateTime timestamp;

  const EloHistoryEntry({
    required this.matchId,
    required this.ratingBefore,
    required this.ratingAfter,
    required this.delta,
    required this.timestamp,
  });

  factory EloHistoryEntry.fromJson(Map<String, dynamic> json) {
    return EloHistoryEntry(
      matchId: json['matchId'] as String,
      ratingBefore: json['ratingBefore'] as int,
      ratingAfter: json['ratingAfter'] as int,
      delta: json['delta'] as int,
      timestamp: (json['timestamp'] as Timestamp).toDate(),
    );
  }

  factory EloHistoryEntry.dummy(int ratingAfter, {int delta = 0}) {
    return EloHistoryEntry(
      matchId: '',
      ratingBefore: ratingAfter - delta,
      ratingAfter: ratingAfter,
      delta: delta,
      timestamp: DateTime.now(),
    );
  }
}
