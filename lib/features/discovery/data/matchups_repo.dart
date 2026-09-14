import 'dart:async';
import 'dart:developer' show log;
import 'dart:math' show Random;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:hooper/features/discovery/data/matchup.dart';
import 'package:hooper/features/location/data/geohash.dart';

class ProposalException implements Exception {
  final String message;
  final String code;
  ProposalException(this.code, this.message);

  @override
  String toString() => 'ProposeMatchException($code): $message';
}

class ProposalResponse {
  String requestId;
  String chatId;

  ProposalResponse({required this.requestId, required this.chatId});

  factory ProposalResponse.fromJson(Map<String, dynamic> data) {
    return ProposalResponse(
      chatId: data['chatId'] as String,
      requestId: data['matchRequestId'] as String,
    );
  }
}

class MatchupScanError {
  String what;
  MatchupScanError(this.what);
}

const _cellLimit = 50;

class FirestoreMatchupRepository {
  FirestoreMatchupRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  Stream<List<Matchup>> nearbyMatchups({
    required GeoPoint? center,
    required double radiusKm,
    required String excludeUserId,
  }) {
    if (center == null) {
      return Stream.empty();
    }
    final precision = geohashPrecisionForRadiusKm(radiusKm);
    final centerHash = geohashEncode(
      center.latitude,
      center.longitude,
      precision: precision,
    );
    final cells = [centerHash, ...geohashNeighbors(centerHash)];

    // Picked once per call (i.e. once per subscription — a pull-to-refresh
    // invalidates the provider and calls this again with a fresh threshold),
    // so a dense cell samples a different slice of its shardKey range each
    // time instead of always returning the same users in the same order.
    final threshold = Random().nextDouble();

    final controller = StreamController<List<Matchup>>.broadcast();
    final perCellDocs = <int, Map<String, Map<String, dynamic>>>{};
    // Two subscriptions per cell (shardKey >= threshold, then the wraparound
    // shardKey < threshold) so together they still cover the whole cell.
    final haveFirstEmission = List<bool>.filled(cells.length * 2, false);
    final subs = <StreamSubscription>[];
    Set<String> restrictedUserIds = {};

    Future<void> fetchBlockLists() async {
      try {
        final myBlocks = await _firestore
            .collection("preferences")
            .doc(excludeUserId)
            .get();
        final blockedByMe = (myBlocks['blockedUsers'] as List? ?? [])
            .cast<String>();

        final blockedByThem = await _firestore
            .collection("preferences")
            .doc(excludeUserId)
            .get();
        final blockedMe = (blockedByThem['blockedBy'] as List? ?? [])
            .cast<String>();

        restrictedUserIds = {...blockedByMe, ...blockedMe};
      } catch (e) {
        log(e.toString());
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
        final status = data['status'] as String? ?? "active";
        if (status != 'active') continue;
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
        if (distanceKm > radiusKm) {
          continue;
        }

        results.add(
          Matchup.fromJson({
            ...data,
            'id': entry.key,
            'distanceKm': distanceKm,
          }),
        );
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
        final cell = cells[i];
        final primaryIndex = i * 2;
        final wraparoundIndex = i * 2 + 1;

        // Capped per cell so a dense area (thousands of users in one
        // geohash cell) can't turn this into an unbounded fetch. Split into
        // two bounded queries — shardKey >= threshold, then the wraparound
        // shardKey < threshold — instead of one, so together they still
        // cover the whole cell while each fetch only ever samples a random
        // slice of it (needs the (geohash, shardKey) composite index in
        // rules/firestore.indexes.json).
        final primarySub = _firestore
            .collection('playerProfiles')
            .where('geohash', isGreaterThanOrEqualTo: cell)
            .where('geohash', isLessThan: '$cell~')
            .where('shardKey', isGreaterThanOrEqualTo: threshold)
            .orderBy('geohash')
            .orderBy('shardKey')
            .limit(_cellLimit)
            .snapshots()
            .listen((snap) {
              perCellDocs[primaryIndex] = {
                for (final d in snap.docs) d.id: d.data(),
              };
              haveFirstEmission[primaryIndex] = true;
              emit();
            }, onError: controller.addError);
        subs.add(primarySub);

        final wraparoundSub = _firestore
            .collection('playerProfiles')
            .where('geohash', isGreaterThanOrEqualTo: cell)
            .where('geohash', isLessThan: '$cell~')
            .where('shardKey', isLessThan: threshold)
            .orderBy('geohash')
            .orderBy('shardKey')
            .limit(_cellLimit)
            .snapshots()
            .listen((snap) {
              perCellDocs[wraparoundIndex] = {
                for (final d in snap.docs) d.id: d.data(),
              };
              haveFirstEmission[wraparoundIndex] = true;
              emit();
            }, onError: controller.addError);
        subs.add(wraparoundSub);
      }
    });

    controller.onCancel = () {
      for (final sub in subs) {
        sub.cancel();
      }
    };

    return controller.stream;
  }

  Future<ProposalResponse> proposeMatch({
    required String court,
    required String targetId,
    required DateTime scheduledTime,
    required bool private,
    required bool friendly,
    required GeoPoint location,
  }) async {
    try {
      final result = await _functions.httpsCallable('proposeMatch').call({
        'targetId': targetId,
        'court': court,
        'scheduledTime': scheduledTime.toUtc().toIso8601String(),
        'latitude': location.latitude,
        'longitude': location.longitude,
        'friendly': friendly,
        'priv': private,
      });

      final data = Map<String, dynamic>.from(result.data as Map);
      return ProposalResponse.fromJson(data);
    } on FirebaseFunctionsException catch (e) {
      throw ProposalException(
        e.code,
        e.message ?? 'Could not send challenge. Try again.',
      );
    }
  }
}
