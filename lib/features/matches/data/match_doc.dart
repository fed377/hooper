import 'package:cloud_firestore/cloud_firestore.dart';

enum MatchStatus { scheduled, awaitingConfirmation, confirmed, disputed, cancelled, inProgress }

MatchStatus matchStatusFromString(String value) {
  switch (value) {
    case 'scheduled':
      return .scheduled;
    case 'awaiting_confirmation':
      return .awaitingConfirmation;
    case 'confirmed':
      return .confirmed;
    case 'disputed':
      return .disputed;
    case 'cancelled':
      return .cancelled;
    case 'in_progress':
      return .inProgress;
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
  final GeoPoint location;

  MatchDoc({
    required this.id,
    required this.mode,
    required this.sideAId,
    required this.sideBId,
    required this.court,
    required this.scheduledTime,
    required this.confirmedAt,
    required this.status,
    required this.scoreA,
    required this.scoreB,
    required this.eloDeltaA,
    required this.eloDeltaB,
    required this.scoreSubmissions,
    required this.appearedIds,
    required this.location,
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
      location: json['location'] as GeoPoint? ?? GeoPoint(0, 0),
    );
  }

  factory MatchDoc.dummy() {
    return MatchDoc(
      id: '',
      mode: '',
      sideAId: '',
      sideBId: '',
      court: '',
      scheduledTime: .now(),
      confirmedAt: .now(),
      status: MatchStatus.cancelled,
      appearedIds: [''],
      scoreA: 5,
      scoreB: 11,
      eloDeltaA: 12,
      eloDeltaB: -12,
      scoreSubmissions: {},
      location: GeoPoint(0, 0),
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
