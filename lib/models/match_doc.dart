import 'package:cloud_firestore/cloud_firestore.dart';

enum MatchStatus { scheduled, awaitingConfirmation, confirmed, disputed, cancelled, inProgress }

MatchStatus matchStatusFromString(String value) {
  switch (value) {
    case 'scheduled':
      return MatchStatus.scheduled;
    case 'awaiting_confirmation':
      return MatchStatus.awaitingConfirmation;
    case 'confirmed':
      return MatchStatus.confirmed;
    case 'disputed':
      return MatchStatus.disputed;
    case 'cancelled':
      return MatchStatus.cancelled;
    case 'in_progress':
      return MatchStatus.inProgress;
    default:
      throw ArgumentError('Unknown match status: $value');
  }
}

class MatchDoc {
  final String id;
  final String mode;
  final String sideAId;
  final String sideBId;
  final String court;
  final DateTime scheduledTime;
  final DateTime? confirmedAt;
  final MatchStatus status;
  final int? scoreA;
  final int? scoreB;
  final int? eloDeltaA;
  final int? eloDeltaB;
  final Map<String, dynamic>? scoreSubmissions;
  final List<String>? appearedIds;

  MatchDoc({
    required this.id,
    required this.mode,
    required this.sideAId,
    required this.sideBId,
    required this.court,
    required this.scheduledTime,
    required this.confirmedAt,
    required this.status,
    this.scoreA,
    this.scoreB,
    this.eloDeltaA,
    this.eloDeltaB,
    this.scoreSubmissions,
    required this.appearedIds,
  });

  //Provide ID as extra json parameter
  factory MatchDoc.fromJson(Map<String, dynamic> json) {
    return MatchDoc(
      id: json['id'] as String,
      mode: json['mode'] as String,
      sideAId: json['sideAId'] as String,
      sideBId: json['sideBId'] as String,
      court: json['court'] as String,
      scheduledTime: (json['scheduledTime'] as Timestamp).toDate(),
      confirmedAt: (json['confirmedAt'] as Timestamp?)?.toDate(),
      status: matchStatusFromString(json['status'] as String),
      scoreA: json['scoreA'] as int?,
      scoreB: json['scoreB'] as int?,
      eloDeltaA: json['eloDeltaA'] as int?,
      eloDeltaB: json['eloDeltaB'] as int?,
      scoreSubmissions: (json['scoreSubmissions'] as Map?)?.cast<String, dynamic>(),
      appearedIds: (json['appearedIds'] as List?)?.cast<String>(),
    );
  }

  factory MatchDoc.dummy() {
    return MatchDoc(
      id: '',
      mode: '',
      sideAId: '',
      sideBId: '',
      court: '',
      scheduledTime: DateTime.now(),
      confirmedAt: DateTime.now(),
      status: MatchStatus.cancelled,
      appearedIds: [''],
    );
  }

  String? mySide(String uid) {
    if (uid == sideAId) return 'A';
    if (uid == sideBId) return 'B';
    return null;
  }

  int? myEloDelta(String uid) => mySide(uid) == 'A' ? eloDeltaA : (mySide(uid) == 'B' ? eloDeltaB : null);

  bool hasSubmitted(String uid) {
    final side = mySide(uid);
    if (side == null) return false;
    return scoreSubmissions?[side] != null;
  }

  String otherParticipant(String myId) => myId == sideAId ? sideBId : sideAId;

  (int, int)? reportedBy(String side) {
    final sub = scoreSubmissions?[side] as Map?;
    if (sub == null) return null;
    final scoreA = sub['scoreA'] as int;
    final scoreB = sub['scoreB'] as int;
    return side == 'A' ? (scoreA, scoreB) : (scoreB, scoreA);
  }
}
