import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:hooper/models/chat.dart';
import 'package:hooper/models/chat_message.dart';
import 'package:hooper/models/match_request_doc.dart';

import '../../models/match_doc.dart';
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
      return MatchDoc.fromJson({...data, 'id': snap.id});
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
  Stream<List<MatchDoc>> watchLockedMatches(String userId) {
    return _firestore.collection('playerProfiles').doc(userId).snapshots().asyncExpand((userSnap) {
      if (!userSnap.exists) {
        return Stream.value([]);
      }

      final data = userSnap.data();
      final List<String> lockedMatchIds = (data?["lockedMatchIds"] as List?)?.cast<String>() ?? const [];

      if (lockedMatchIds.isEmpty) {
        return Stream.value([]);
      }

      final constrainedIds = lockedMatchIds.take(30).toList();

      return _firestore
          .collection('matches')
          .where(FieldPath.documentId, whereIn: constrainedIds)
          .snapshots()
          .map(
            (matchSnap) => matchSnap.docs.map((d) {
              final matchData = d.data();
              return MatchDoc.fromJson({
                ...matchData,
                'id': d.id,
                'createdAt': (matchData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
                'startTime': (matchData['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
              });
            }).toList(),
          );
    });
  }

  @override
  Future<void> sendMessage({required String chatId, required String uid, required String text}) async {
    final chatRef = _firestore.collection('chats').doc(chatId);
    final messageRef = chatRef.collection('messages').doc();

    final chatSnap = await chatRef.get();
    final batch = _firestore.batch();
    final ids = chatId.split('_');

    if (!chatSnap.exists) {
      batch.set(chatRef, {
        'participantIds': ids,
        'lastMatchRequestId': null,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessagePreview': text,
        'lastMessageRead': {uid: messageRef.id},
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
        'courtText': ?courtText,
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
  Future<void> startMatch(String matchId) async {
    try {
      await _functions.httpsCallable('startMatch').call({'matchId': matchId});
    } on FirebaseFunctionsException catch (e) {
      throw MatchActionException(e.code, e.message ?? 'Could not start.');
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

  @override
  Future<void> readMessage({required String userId, required String chatId, required String messageId}) async {
    try {
      await _firestore.collection('chats').doc(chatId).update({'lastMessageRead.$userId': messageId});
    } on FirebaseFunctionsException catch (e) {
      throw MatchActionException(e.code, e.message ?? 'Could not update last read message.');
    }
  }
}
