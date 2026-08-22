import 'dart:async';
import 'dart:developer' show log;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:hooper/data/geohash/geohash.dart';
import 'package:hooper/data/repos/matchup_repo.dart';
import 'package:hooper/models/matchup.dart';

class ProposalResponse {
  String requestId;
  String chatId;

  ProposalResponse({required this.requestId, required this.chatId});

  factory ProposalResponse.fromJson(Map<String, dynamic> data) {
    return ProposalResponse(chatId: data['chatId'] as String, requestId: data['matchRequestId'] as String);
  }
}

class MatchupScanError {
  String what;
  MatchupScanError(this.what);
}

class FirestoreMatchupRepository implements MatchupRepository {
  FirestoreMatchupRepository({FirebaseFirestore? firestore, FirebaseFunctions? functions})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _functions = functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  @override
  Stream<List<Matchup>> nearbyMatchups({
    required GeoPoint? center,
    required double radiusKm,
    required String excludeUserId,
  }) {
    if (center == null) {
      return Stream.empty();
    }
    final precision = geohashPrecisionForRadiusKm(radiusKm);
    final centerHash = geohashEncode(center.latitude, center.longitude, precision: precision);
    final cells = [centerHash, ...geohashNeighbors(centerHash)];

    final controller = StreamController<List<Matchup>>.broadcast();
    final perCellDocs = <int, Map<String, Map<String, dynamic>>>{};
    final haveFirstEmission = List<bool>.filled(cells.length, false);
    final subs = <StreamSubscription>[];
    Set<String> restrictedUserIds = {};

    Future<void> fetchBlockLists() async {
      try {
        final myBlocks = await _firestore.collection("playerProfiles").doc(excludeUserId).get();
        final blockedByMe = (myBlocks['blockedUsers'] as List? ?? []).cast<String>();

        final blockedByThem = await _firestore.collection("playerProfiles").doc(excludeUserId).get();
        final blockedMe = (blockedByThem['blockedBy'] as List? ?? []).cast<String>();

        restrictedUserIds = {...blockedByMe, ...blockedMe};
      } catch (e) {
        throw MatchupScanError(e.toString());
      }
    }

    void emit() {
      if (!haveFirstEmission.every((done) => done)) return;

      final merged = <String, Map<String, dynamic>>{};
      for (final cellMap in perCellDocs.values) {
        merged.addAll(cellMap);
      }

      final results = <Matchup>[];
      for (final entry in merged.entries) {
        if (entry.key == excludeUserId) continue;
        if (restrictedUserIds.contains(entry.key)) continue;

        final data = entry.value;
        final homeLocation = data['homeLocation'] as GeoPoint?;
        final status = data['status'] as String? ?? "normal";
        if (status == 'banned') continue;
        if (homeLocation == null) continue;

        final distanceKm =
            (100 *
                    haversineDistanceKm(
                      center.latitude,
                      center.longitude,
                      homeLocation.latitude,
                      homeLocation.longitude,
                    ))
                .round() /
            100;
        if (distanceKm > radiusKm) continue;

        results.add(Matchup.fromJson({...data, 'id': entry.key, 'distanceKm': distanceKm}));
      }
      results.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
      controller.add(results);
    }

    fetchBlockLists().then((_) {
      log("Restricting");
      for (final x in restrictedUserIds) {
        log(x);
      }
      for (var i = 0; i < cells.length; i++) {
        final cellIndex = i;
        final cell = cells[i];
        final sub = _firestore
            .collection('playerProfiles')
            .orderBy('geohash')
            .startAt([cell])
            .endAt(['$cell~'])
            .where(FieldPath.documentId)
            .snapshots()
            .listen((snap) {
              perCellDocs[cellIndex] = {for (final d in snap.docs) d.id: d.data()};
              haveFirstEmission[cellIndex] = true;
              emit();
            }, onError: controller.addError);
        subs.add(sub);
      }
    });

    controller.onCancel = () {
      for (final sub in subs) {
        sub.cancel();
      }
    };

    return controller.stream;
  }

  @override
  Future<ProposalResponse> proposeMatch({
    required String court,
    required String targetId,
    required DateTime scheduledTime,
  }) async {
    try {
      final result = await _functions.httpsCallable('proposeMatch').call({
        'targetId': targetId,
        'court': court,
        'scheduledTime': scheduledTime.toIso8601String(),
      });

      final data = Map<String, dynamic>.from(result.data as Map);
      return ProposalResponse.fromJson(data);
    } on FirebaseFunctionsException catch (e) {
      throw ProposeMatchException(e.code, e.message ?? 'Could not send challenge. Try again.');
    }
  }
}
