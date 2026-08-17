import 'package:hooper/models/chat.dart';

import '../../models/match.dart';

abstract class MatchRepository {
  Stream<MatchDoc> watchMatch(String matchId);
  Stream<List<MatchRequestDoc>> watchRequestsToId(String uid);
  Stream<List<MatchRequestDoc>> watchRequestsFromId(String uid);
  Stream<List<Chat>> watchMyChats(String uid);
  Stream<List<MatchDoc>> watchLockedMatches(String userId);
  Stream<Chat> watchChat(String chatId);
  Future<void> sendMessage({required String chatId, required String uid, required String text});
  Future<void> updateMatchRequestDetails({required String matchRequestId, String? courtText, DateTime? scheduledTime});
  Future<void> cancelRequest(String matchRequestId);
  Future<String> acceptRequest(String matchRequestId);
  Future<void> declineRequest(String matchRequestId);
  Stream<MatchRequestDoc> watchMatchRequest(String matchRequestId);
  Stream<List<ChatMessage>> watchMessages(String matchRequestId);
  Future<void> cancelMatch(String matchId);
  Future<void> submitScore({required String matchId, required int myScore, required int opponentScore});
  Future<void> startMatch(String matchId);
}

class MatchActionException implements Exception {
  final String code;
  final String message;
  MatchActionException(this.code, this.message);

  @override
  String toString() => 'MatchActionException($code): $message';
}
