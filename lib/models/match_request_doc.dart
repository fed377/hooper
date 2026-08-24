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

  factory MatchRequestDoc.dummy() {
    return MatchRequestDoc(
      id: '',
      mode: '',
      initiatorId: '',
      targetId: '',
      court: '',
      scheduledTime: DateTime(3000),
      status: MatchRequestStatus.accepted,
      chatId: '',
      createdAt: DateTime.now(),
    );
  }

  bool isInitiator(String uid) => uid == initiatorId;

  /// The other participant's uid, relative to [uid].
  String otherParticipant(String uid) => isInitiator(uid) ? targetId : initiatorId;
}
