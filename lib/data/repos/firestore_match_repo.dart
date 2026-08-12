import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:hooper/models/chat.dart';

import '../../models/match.dart';
import 'match_repo.dart';

class FirestoreMatchRepository implements MatchRepository {
  FirestoreMatchRepository({FirebaseFirestore? firestore, FirebaseFunctions? functions})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _functions = functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  @override
  Stream<MatchDoc> watchMatch(String matchId) {
    return _firestore.collection('matches').doc(matchId).snapshots().map((snap) {
      final data = snap.data()!;
      return MatchDoc.fromJson({
        ...data,
        'id': snap.id,
        'scheduledTime': (data['scheduledTime'] as Timestamp).toDate(),
      });
    });
  }

  @override
  Stream<List<MatchRequestDoc>> watchRequestsToId(String uid) {
    return _firestore
        .collection('matchRequests')
        .where('targetId', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs.map((d) => _requestFromSnap(d)).toList());
  }

  @override
  Stream<List<MatchRequestDoc>> watchRequestsFromId(String uid) {
    return _firestore
        .collection('matchRequests')
        .where('initiatorId', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs.map((d) => _requestFromSnap(d)).toList());
  }

  @override
  Stream<List<Chat>> watchMyChats(String uid) {
    return _firestore.collection('chats').where('participantIds', arrayContains: uid).snapshots().map((snap) {
      final chats = snap.docs.map(_chatFromSnap).toList();
      chats.sort((a, b) {
        final aTime = a.lastMessageAt ?? a.createdAt;
        final bTime = b.lastMessageAt ?? b.createdAt;
        return bTime.compareTo(aTime); // most recent first
      });
      return chats;
    });
  }

  @override
  Stream<Chat> watchChat(String chatId) {
    return _firestore.collection('chats').doc(chatId).snapshots().map((snap) {
      if (!snap.exists) {
        // Reachable now that MatchupCard's chat button opens a chat
        // with no proposal ever having been sent — there's no doc
        // here yet. Synthesize a display-only placeholder rather than
        // throwing: participantIds comes from splitting chatId itself
        // (uidA_uidB, sorted — see pairChatId), which works because
        // Firebase Auth uids never contain underscores. Never written
        // anywhere; sendMessage creates the real doc on first message.
        return Chat(id: chatId, participantIds: chatId.split('_'), lastMatchRequestId: null, createdAt: DateTime.now());
      }
      return _chatFromSnap(snap);
    });
  }

  Chat _chatFromSnap(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data()!;
    return Chat.fromJson({
      ...data,
      'id': snap.id,
      'createdAt': (data['createdAt'] as Timestamp).toDate(),
      'lastMessageAt': (data['lastMessageAt'] as Timestamp?)?.toDate(),
    });
  }

  @override
  Stream<MatchRequestDoc> watchMatchRequest(String matchRequestId) {
    return _firestore.collection('matchRequests').doc(matchRequestId).snapshots().map((snap) => _requestFromSnap(snap));
  }

  MatchRequestDoc _requestFromSnap(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data()!;
    return MatchRequestDoc.fromJson({
      ...data,
      'id': snap.id,
      'scheduledTime': (data['scheduledTime'] as Timestamp).toDate(),
      'createdAt': (data['createdAt'] as Timestamp).toDate(),
    });
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) {
            final data = d.data();
            return ChatMessage.fromJson({
              ...data,
              'id': d.id,
              'createdAt': (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            });
          }).toList(),
        );
  }

  @override
  Future<void> sendMessage({required String chatId, required String uid, required String text}) async {
    final chatRef = _firestore.collection('chats').doc(chatId);
    final messageRef = chatRef.collection('messages').doc();

    final chatSnap = await chatRef.get();
    final batch = _firestore.batch();

    if (!chatSnap.exists) {
      batch.set(chatRef, {
        'participantIds': chatId.split('_'),
        'lastMatchRequestId': null,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessagePreview': text,
      });
    } else {
      batch.update(chatRef, {'lastMessageAt': FieldValue.serverTimestamp(), 'lastMessagePreview': text});
    }

    batch.set(messageRef, {
      'isSystem': false,
      'senderId': uid,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return batch.commit();
  }

  @override
  Future<void> updateMatchRequestDetails({
    required String matchRequestId,
    String? courtText,
    DateTime? scheduledTime,
  }) async {
    try {
      await _functions.httpsCallable('updateMatchRequest').call({
        'matchRequestId': matchRequestId,
        if (courtText != null) 'courtText': courtText,
        if (scheduledTime != null) 'scheduledTime': scheduledTime.toIso8601String(),
      });
    } on FirebaseFunctionsException catch (e) {
      throw MatchActionException(e.code, e.message ?? 'Could not update the proposal.');
    }
  }

  @override
  Future<void> cancelRequest(String matchRequestId) async {
    try {
      await _functions.httpsCallable('cancelRequest').call({'matchRequestId': matchRequestId});
    } on FirebaseFunctionsException catch (e) {
      throw MatchActionException(e.code, e.message ?? 'Could not cancel the request.');
    }
  }

  @override
  Stream<List<String>?> watchMyLockedMatchIds(String uid) {
    return _firestore
        .collection('playerProfiles')
        .doc(uid)
        .snapshots()
        .map((snap) => (snap.data()?['lockedMatchId'] as List?)?.cast<String>());
  }

  @override
  Future<String> acceptRequest(String matchRequestId) async {
    try {
      final result = await _functions.httpsCallable('acceptRequest').call({'matchRequestId': matchRequestId});
      final data = Map<String, dynamic>.from(result.data as Map);
      return data['matchId'] as String;
    } on FirebaseFunctionsException catch (e) {
      throw MatchActionException(e.code, e.message ?? 'Could not accept.');
    }
  }

  @override
  Future<void> declineRequest(String matchRequestId) async {
    try {
      await _functions.httpsCallable('declineRequest').call({'matchRequestId': matchRequestId});
    } on FirebaseFunctionsException catch (e) {
      throw MatchActionException(e.code, e.message ?? 'Could not decline.');
    }
  }

  @override
  Future<void> cancelMatch(String matchId) async {
    try {
      await _functions.httpsCallable('cancelMatch').call({'matchId': matchId});
    } on FirebaseFunctionsException catch (e) {
      throw MatchActionException(e.code, e.message ?? 'Could not cancel.');
    }
  }

  @override
  Future<void> submitScore({required String matchId, required int myScore, required int opponentScore}) async {
    try {
      await _functions.httpsCallable('submitScore').call({
        'matchId': matchId,
        'myScore': myScore,
        'opponentScore': opponentScore,
      });
    } on FirebaseFunctionsException catch (e) {
      throw MatchActionException(e.code, e.message ?? 'Could not submit score.');
    }
  }
}
