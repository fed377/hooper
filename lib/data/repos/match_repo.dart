import '../../models/match.dart';

abstract class MatchRepository {
  Stream<MatchDoc> watchMatch(String matchId);

  Stream<List<IncomingRequest>> watchIncomingRequests(String uid);

  Stream<String?> watchMyLockedMatchId(String uid);

  Future<String> acceptRequest(String matchRequestId);
  Future<void> declineRequest(String matchRequestId);
  Future<void> cancelMatch(String matchId);
  Future<void> submitScore({
    required String matchId,
    required int myScore,
    required int opponentScore,
  });
}

class MatchActionException implements Exception {
  final String code;
  final String message;
  MatchActionException(this.code, this.message);

  @override
  String toString() => 'MatchActionException($code): $message';
}