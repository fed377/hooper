enum MatchStatus { scheduled, awaitingConfirmation, confirmed, disputed, cancelled }

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
    default:
      throw ArgumentError('Unknown match status: $value');
  }
}

class MatchDoc {
  final String id;
  final String mode;
  final String sideAId;
  final String sideBId;
  final String courtId;
  final DateTime scheduledTime;
  final MatchStatus status;
  final int? scoreA;
  final int? scoreB;
  final int? eloDeltaA;
  final int? eloDeltaB;

  MatchDoc({
    required this.id,
    required this.mode,
    required this.sideAId,
    required this.sideBId,
    required this.courtId,
    required this.scheduledTime,
    required this.status,
    this.scoreA,
    this.scoreB,
    this.eloDeltaA,
    this.eloDeltaB,
  });

  factory MatchDoc.fromJson(Map<String, dynamic> json) {
    return MatchDoc(
      id: json['id'] as String,
      mode: json['mode'] as String,
      sideAId: json['sideAId'] as String,
      sideBId: json['sideBId'] as String,
      courtId: json['courtId'] as String,
      scheduledTime: (json['scheduledTime'] as DateTime),
      status: matchStatusFromString(json['status'] as String),
      scoreA: json['scoreA'] as int?,
      scoreB: json['scoreB'] as int?,
      eloDeltaA: json['eloDeltaA'] as int?,
      eloDeltaB: json['eloDeltaB'] as int?,
    );
  }

  String? mySide(String uid) {
    if (uid == sideAId) return 'A';
    if (uid == sideBId) return 'B';
    return null;
  }

  int? myElo(String uid) => mySide(uid) == 'A' ? eloDeltaA : (mySide(uid) == 'B' ? eloDeltaB : null);
}

class IncomingRequest {
  final String id;
  final String initiatorId;
  final String courtId;
  final DateTime scheduledTime;

  IncomingRequest({required this.id, required this.initiatorId, required this.courtId, required this.scheduledTime});

  factory IncomingRequest.fromJson(Map<String, dynamic> json) {
    return IncomingRequest(
      id: json['id'] as String,
      initiatorId: json['initiatorId'] as String,
      courtId: json['courtId'] as String,
      scheduledTime: json['scheduledTime'] as DateTime,
    );
  }
}
