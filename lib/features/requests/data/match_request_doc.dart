import 'package:cloud_firestore/cloud_firestore.dart';

enum MatchRequestStatus { pending, accepted, declined, expired, withdrawn, finished }

MatchRequestStatus matchRequestStatusFromString(String value) {
  switch (value) {
    case 'pending':
      return .pending;
    case 'accepted':
      return .accepted;
    case 'declined':
      return .declined;
    case 'expired':
      return .expired;
    case 'withdrawn':
      return .withdrawn;
    case 'finished':
      return .finished;
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
  final GeoPoint location;
  final bool private;
  final bool friendly;

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
    required this.location,
    required this.private,
    required this.friendly,
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
      location: (json['location'] as GeoPoint?) ?? GeoPoint(0, 0),
      private: (json['private'] ?? false) as bool,
      friendly: (json['friendly'] ?? false) as bool,
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
      createdAt: .now(),
      location: GeoPoint(0, 0),
      private: false,
      friendly: false,
    );
  }

  bool isInitiator(String uid) => uid == initiatorId;

  /// The other participant's uid, relative to [uid].
  String otherParticipant(String uid) => isInitiator(uid) ? targetId : initiatorId;
}
