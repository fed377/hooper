import 'package:skeletonizer/skeletonizer.dart';

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

  factory ChatMessage.dummy({bool isSystem = false, String senderId = 'other', int words = 5}) {
    return ChatMessage(id: senderId, text: BoneMock.words(words), isSystem: isSystem, createdAt: DateTime.now());
  }

  static List<ChatMessage> dummyList(String uid) {
    final x = ChatMessage.dummy;
    return [x(isSystem: true), x(words: 7), x(senderId: uid)];
  }
}
