import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/court.dart';
import '../models/match.dart';
import '../models/matchup.dart';
import 'repos/firestore_match_repo.dart';
import 'repos/firestore_matchups.dart';
import 'repos/match_repo.dart';
import 'repos/matchup_repo.dart';

// --- Auth -------------------------------------------------------------

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// Throws if read before sign-in — screens behind an auth gate can rely
/// on this always having a value; unauthenticated screens should read
/// authStateProvider directly instead.
final currentUserIdProvider = Provider<String>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) {
    throw StateError('currentUserIdProvider read before sign-in.');
  }
  return user.uid;
});

final profileExistsProvider = StreamProvider.family<bool, String>((ref, uid) {
  return FirebaseFirestore.instance.collection('playerProfiles').doc(uid).snapshots().map((snap) => snap.exists);
});

// --- Repositories -------------------------------------------------------

final matchupRepositoryProvider = Provider<MatchupRepository>((ref) {
  return FirestoreMatchupRepository();
});

final matchRepositoryProvider = Provider<MatchRepository>((ref) {
  return FirestoreMatchRepository();
});

// --- Discovery feed -------------------------------------------------------

/// Center point for the "nearby" query. Hardcoded for now — swap for a
/// real geolocation provider (e.g. via the `geolocator` package) once
/// location permissions are wired up. Every screen downstream should
/// depend on THIS provider, not call geolocation directly, so swapping
/// the source later doesn't ripple through the UI.
final searchCenterProvider = Provider<GeoPoint>((ref) {
  return const GeoPoint(37.7749, -122.4194);
});

final nearbyMatchupsProvider = StreamProvider<List<Matchup>>((ref) {
  final repo = ref.watch(matchupRepositoryProvider);
  final center = ref.watch(searchCenterProvider);
  final uid = ref.watch(currentUserIdProvider);
  return repo.nearbyMatchups(center: center, radiusKm: 10, userId: uid);
});

final courtsProvider = StreamProvider<List<Court>>((ref) {
  return FirebaseFirestore.instance
      .collection('courts')
      .where('verified', isEqualTo: true)
      .snapshots()
      .map((snap) => snap.docs.map((d) => Court.fromJson({...d.data(), 'id': d.id})).toList());
});

// --- Match lifecycle -------------------------------------------------------

final incomingRequestsProvider = StreamProvider<List<IncomingRequest>>((ref) {
  final repo = ref.watch(matchRepositoryProvider);
  final uid = ref.watch(currentUserIdProvider);
  return repo.watchIncomingRequests(uid);
});

/// Null when the user isn't currently locked into anything.
final myLockedMatchIdProvider = StreamProvider<String?>((ref) {
  final repo = ref.watch(matchRepositoryProvider);
  final uid = ref.watch(currentUserIdProvider);
  return repo.watchMyLockedMatchId(uid);
});

/// Family provider: one live stream per matchId, so the score-entry and
/// locked screens can both watch the same match without duplicating
/// Firestore listeners.
final matchProvider = StreamProvider.family<MatchDoc, String>((ref, matchId) {
  final repo = ref.watch(matchRepositoryProvider);
  return repo.watchMatch(matchId);
});
