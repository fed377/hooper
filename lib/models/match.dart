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
  });

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

enum MatchRequestStatus { pending, accepted, declined, expired, withdrawn, finished }

MatchRequestStatus matchRequestStatusFromString(String value) {
  switch (value) {
    case 'pending':
      return MatchRequestStatus.pending;
    case 'accepted':
      return MatchRequestStatus.accepted;
    case 'declined':
      return MatchRequestStatus.declined;
    case 'expired':
      return MatchRequestStatus.expired;
    case 'withdrawn':
      return MatchRequestStatus.withdrawn;
    case 'finished':
      return MatchRequestStatus.finished;
    default:
      throw ArgumentError('Unknown match request status: $value');
  }
}

class MatchRequestDoc {
  final String id;
  final String mode;
  final String initiatorId;
  final String targetId;
  final String court;
  final DateTime scheduledTime;
  final MatchRequestStatus status;
  final String? matchId; // set once accepted
  final String chatId;
  final DateTime createdAt;

  MatchRequestDoc({
    required this.id,
    required this.mode,
    required this.initiatorId,
    required this.targetId,
    required this.court,
    required this.scheduledTime,
    required this.status,
    this.matchId,
    required this.chatId,
    required this.createdAt,
  });

  factory MatchRequestDoc.fromJson(Map<String, dynamic> json) {
    return MatchRequestDoc(
      id: json['id'] as String,
      mode: json['mode'] as String,
      initiatorId: json['initiatorId'] as String,
      targetId: json['targetId'] as String,
      court: json['court'] as String,
      scheduledTime: json['scheduledTime'] as DateTime,
      status: matchRequestStatusFromString(json['status'] as String),
      matchId: json['matchId'] as String?,
      chatId: json['chatId'] as String,
      createdAt: json['createdAt'] as DateTime,
    );
  }

  bool isInitiator(String uid) => uid == initiatorId;

  /// The other participant's uid, relative to [uid].
  String otherParticipant(String uid) => isInitiator(uid) ? targetId : initiatorId;
}

class ChatMessage {
  final String id;
  final String? senderId; // null for system messages
  final String text;
  final bool isSystem;
  final String? matchRequestId;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    this.senderId,
    required this.text,
    required this.isSystem,
    this.matchRequestId,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      senderId: json['senderId'] as String?,
      text: json['text'] as String,
      isSystem: json['isSystem'] as bool? ?? false,
      matchRequestId: json['matchRequestId'] as String?,
      createdAt: json['createdAt'] as DateTime,
    );
  }
}
