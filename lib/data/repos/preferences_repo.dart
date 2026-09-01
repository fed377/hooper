import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:hooper/models/user_preferences.dart';

//Report Status: Sent, Reviewing, Finished

class FirestorePreferencesRepository {
  FirestorePreferencesRepository({FirebaseFirestore? firestore, FirebaseFunctions? functions})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<UserPreference> watchMyPreferences(String uid) {
    return _firestore.collection('userPreferences').doc(uid).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) {
        throw StateError('playerProfiles/$uid does not exist yet.');
      }
      return UserPreference.fromJson({'userId': uid, ...data});
    });
  }

  Future<void> _reportUser(String myId, String targetId, String reason, String? matchId) async {
    await _firestore.collection('reports').doc().set({
      'senderId': myId,
      'targetId': targetId,
      'reason': reason,
      'matchId': matchId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<bool> confirmReportUser(
    BuildContext context,
    String myId,
    String targetId,
    String? matchId,
    String targetName, {
    bool canBlock = true,
  }) async {
    String reason = '';
    bool sending = false;
    bool includeMatch = matchId != null;
    return await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Report $targetName"),
          content: Column(
            crossAxisAlignment: .stretch,
            mainAxisSize: .min,
            children: [
              TextField(onChanged: (text) => reason = text),
              if (matchId != null)
                Row(
                  children: [
                    Text("Include Match ID?"),
                    const Spacer(),
                    Checkbox(value: includeMatch, onChanged: (b) => includeMatch = b ?? false),
                  ],
                ),
            ],
          ),
          actions: [
            Column(
              mainAxisSize: .min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        child: Text("Cancel"),
                        onPressed: () {
                          if (sending) return;
                          sending = true;
                          Navigator.of(context).pop(false);
                        },
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: FilledButton(
                        child: Text("Report"),
                        onPressed: () async {
                          if (sending) return;
                          sending = true;
                          await _reportUser(myId, targetId, reason, includeMatch ? matchId : null);
                          if (!context.mounted) return;
                          Navigator.of(context).pop(true);
                        },
                      ),
                    ),
                  ],
                ),
                if (canBlock)
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          child: Text("Report & Block"),
                          onPressed: () async {
                            if (sending) return;
                            sending = true;
                            await _reportUser(myId, targetId, reason, includeMatch ? matchId : null);
                            if (!context.mounted) return;
                            final b = await confirmBlockUser(context, myId, targetId, targetName, canReport: false);
                            if (!context.mounted) return;
                            Navigator.of(context).pop(b);
                          },
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _blockUser(String myId, String targetId) async {
    await _firestore.collection('preferences').doc(myId).set({
      'blockedUsers': FieldValue.arrayUnion([targetId]),
    }, SetOptions(merge: true));
    await _firestore.collection('preferences').doc(targetId).set({
      'blockedBy': FieldValue.arrayUnion([myId]),
    }, SetOptions(merge: true));
  }

  Future<bool> confirmBlockUser(
    BuildContext context,
    String myId,
    String targetId,
    String targetName, {
    bool canReport = true,
  }) async {
    bool sending = false;
    return await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Block $targetName"),
          content: Text("Are you sure you would like to block $targetName?"),
          actions: [
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        child: Text("Cancel"),
                        onPressed: () {
                          if (sending) return;
                          sending = true;
                          Navigator.of(context).pop(false);
                        },
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: FilledButton(
                        child: Text("Block"),
                        onPressed: () async {
                          if (sending) return;
                          sending = true;
                          await _blockUser(myId, targetId);
                          if (!context.mounted) return;
                          Navigator.of(context).pop(true);
                        },
                      ),
                    ),
                  ],
                ),
                if (canReport)
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          child: Text("Block & Report"),
                          onPressed: () async {
                            if (sending) return;
                            sending = true;
                            await _blockUser(myId, targetId);
                            if (!context.mounted) return;
                            final b = await confirmReportUser(
                              context,
                              myId,
                              targetId,
                              null,
                              targetName,
                              canBlock: false,
                            );
                            if (!context.mounted) return;
                            Navigator.of(context).pop(b);
                          },
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
