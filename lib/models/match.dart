enum MatchStatus { scheduled, awaitingConfirmation, confirmed, disputed, cancelled, happening }

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
    case 'happening':
      return MatchStatus.happening;
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
    required this.court,
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
      court: json['court'] as String,
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

enum MatchRequestStatus { pending, accepted, declined, expired, withdrawn }

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
  final String? matchId;
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
