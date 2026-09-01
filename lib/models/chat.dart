class Chat {
  final String id;
  final List<String> participantIds;
  final String? lastMatchRequestId;
  final DateTime createdAt;
  final DateTime? lastMessageAt;
  final String? lastMessagePreview;

  Chat({
    required this.id,
    required this.participantIds,
    this.lastMatchRequestId,
    required this.createdAt,
    this.lastMessageAt,
    this.lastMessagePreview,
  });

  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(
      id: json['id'] as String,
      participantIds: (json['participantIds'] as List).cast<String>(),
      lastMatchRequestId: json['lastMatchRequestId'] as String?,
      createdAt: json['createdAt'] as DateTime,
      lastMessageAt: json['lastMessageAt'] as DateTime?,
      lastMessagePreview: json['lastMessagePreview'] as String?,
    );
  }

  factory Chat.dummy() => Chat(id: '', participantIds: ['uno', 'dos'], createdAt: .now());

  static String pairChatId(String uidA, String uidB) {
    final sorted = [uidA, uidB]..sort();
    return sorted.join('_');
  }

  String otherParticipant(String uid) => participantIds.firstWhere((id) => id != uid);
}
