import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooper/data/repos/firestore_profiles_repo.dart';
import 'package:hooper/data/repos/profiles_repo.dart';
import 'package:hooper/models/chat.dart';
import 'package:hooper/models/player_profile.dart';

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

final isUniqueNameProvider = StreamProvider.family<bool, String>((ref, name) {
  return FirebaseFirestore.instance.collection('usernames').doc(name).snapshots().map((snap) => snap.exists);
});

final myDateOfBirthProvider = StreamProvider.family<DateTime?, String>((ref, uid) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((snap) => (snap.data()?['dateOfBirth'] as Timestamp?)?.toDate());
});

// --- Repositories -------------------------------------------------------

final matchupRepositoryProvider = Provider<MatchupRepository>((ref) {
  return FirestoreMatchupRepository();
});

final matchRepositoryProvider = Provider<MatchRepository>((ref) {
  return FirestoreMatchRepository();
});

final playerProfileRepositoryProvider = Provider<PlayerProfileRepository>((ref) {
  return FirestorePlayerProfileRepository();
});

// --- My Profile Viewing & Editing ---------------------------------------

final myPlayerProfileProvider = StreamProvider<PlayerProfile>((ref) {
  final repo = ref.watch(playerProfileRepositoryProvider);
  final uid = ref.watch(currentUserIdProvider);
  return repo.watchMyProfile(uid);
});

final playerDisplayNameProvider = FutureProvider.family<String, String>((ref, uid) async {
  final doc = await FirebaseFirestore.instance.collection('playerProfiles').doc(uid).get();
  return doc.data()?['displayName'] as String? ?? 'Player';
});

final playerPhotoUrlProvider = FutureProvider.family<String, String>((ref, uid) async {
  final doc = await FirebaseFirestore.instance.collection('playerProfiles').doc(uid).get();
  return doc.data()?['photoUrl'] as String? ?? '';
});

final playerBannerUrlProvider = FutureProvider.family<String, String>((ref, uid) async {
  final doc = await FirebaseFirestore.instance.collection('playerProfiles').doc(uid).get();
  return doc.data()?['bannerUrl'] as String? ?? '';
});

// --- Discovery feed -------------------------------------------------------

/// Center point for the "nearby" query. Hardcoded for now — swap for a
/// real geolocation provider (e.g. via the `geolocator` package) once
/// location permissions are wired up. Every screen downstream should
/// depend on THIS provider, not call geolocation directly, so swapping
/// the source later doesn't ripple through the UI.
final searchCenterProvider = Provider<GeoPoint?>((ref) {
  final profile = ref.watch(myPlayerProfileProvider).value;
  return profile?.homeLocation;
});

final nearbyMatchupsProvider = StreamProvider<List<Matchup>>((ref) {
  final repo = ref.watch(matchupRepositoryProvider);
  final center = ref.watch(searchCenterProvider);
  final uid = ref.watch(currentUserIdProvider);
  return repo.nearbyMatchups(center: center, radiusKm: 10, excludeUserId: uid);
});

final matchupFromIdProvider = FutureProvider.family<Matchup, String>((ref, uid) async {
  final snap = await FirebaseFirestore.instance.collection('playerProfiles').doc(uid).get();
  return Matchup.fromJson({...snap.data()!, 'id': snap.id, 'distanceKm': 100});
});

// --- Match lifecycle -------------------------------------------------------

final incomingRequestsProvider = StreamProvider<List<MatchRequestDoc>>((ref) {
  final repo = ref.watch(matchRepositoryProvider);
  final uid = ref.watch(currentUserIdProvider);
  return repo.watchRequestsToId(uid);
});

final outgoingRequestsProvider = StreamProvider<List<MatchRequestDoc>>((ref) {
  final repo = ref.watch(matchRepositoryProvider);
  final uid = ref.watch(currentUserIdProvider);
  return repo.watchRequestsFromId(uid);
});

final myChatsProvider = StreamProvider<List<Chat>>((ref) {
  final repo = ref.watch(matchRepositoryProvider);
  final uid = ref.watch(currentUserIdProvider);
  return repo.watchMyChats(uid);
});

final chatProvider = StreamProvider.family<Chat, String>((ref, chatId) {
  final repo = ref.watch(matchRepositoryProvider);
  return repo.watchChat(chatId);
});

final matchRequestProvider = StreamProvider.family<MatchRequestDoc, String>((ref, requestId) {
  final repo = ref.watch(matchRepositoryProvider);
  return repo.watchMatchRequest(requestId);
});

final chatMessagesProvider = StreamProvider.family<List<ChatMessage>, String>((ref, chatId) {
  final repo = ref.watch(matchRepositoryProvider);
  return repo.watchMessages(chatId);
});

final myLockedMatchIdsProvider = StreamProvider<List<String>?>((ref) {
  final repo = ref.watch(matchRepositoryProvider);
  final uid = ref.watch(currentUserIdProvider);
  return repo.watchMyLockedMatchIds(uid);
});

final matchProvider = StreamProvider.family<MatchDoc, String>((ref, matchId) {
  final repo = ref.watch(matchRepositoryProvider);
  return repo.watchMatch(matchId);
});


