import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooper/data/repos/firestore_profiles_repo.dart';
import 'package:hooper/data/repos/preferences_repo.dart';
import 'package:hooper/data/repos/profiles_repo.dart';
import 'package:hooper/models/chat.dart';
import 'package:hooper/models/chat_message.dart';
import 'package:hooper/models/match_request_doc.dart';
import 'package:hooper/models/player_profile.dart';

import '../models/match_doc.dart';
import '../models/matchup.dart';
import 'repos/firestore_match_repo.dart';
import 'repos/firestore_matchups.dart';
import 'repos/match_repo.dart';
import 'repos/matchup_repo.dart';

// --- Auth -------------------------------------------------------------

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final currentUserIdProvider = Provider<String>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) {
    throw StateError('currentUserIdProvider read before sign-in.');
  }
  return user.uid;
});

final profileExistsProvider = StreamProvider.autoDispose.family<bool, String>((ref, uid) {
  return FirebaseFirestore.instance.collection('playerProfiles').doc(uid).snapshots().map((snap) => snap.exists);
});

final isUniqueNameProvider = StreamProvider.autoDispose.family<bool, String>((ref, name) {
  return FirebaseFirestore.instance.collection('usernames').doc(name).snapshots().map((snap) => snap.exists);
});

final myDateOfBirthProvider = StreamProvider.autoDispose.family<DateTime?, String>((ref, uid) {
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

final userPreferencesProvider = Provider<FirestorePreferencesRepository>((ref) {
  return FirestorePreferencesRepository();
});

// --- My Profile Viewing & Editing ---------------------------------------

final myPlayerProfileProvider = StreamProvider<PlayerProfile>((ref) {
  final repo = ref.watch(playerProfileRepositoryProvider);
  final uid = ref.watch(currentUserIdProvider);
  return repo.watchMyProfile(uid);
});

final playerDisplayNameProvider = FutureProvider.autoDispose.family<String, String>((ref, uid) async {
  final doc = await FirebaseFirestore.instance.collection('playerProfiles').doc(uid).get();
  return doc.data()?['displayName'] as String? ?? 'Player';
});

final playerPhotoUrlProvider = FutureProvider.autoDispose.family<String, String>((ref, uid) async {
  final doc = await FirebaseFirestore.instance.collection('playerProfiles').doc(uid).get();
  return doc.data()?['photoUrl'] as String? ?? '';
});

final playerBannerUrlProvider = FutureProvider.autoDispose.family<String, String>((ref, uid) async {
  final doc = await FirebaseFirestore.instance.collection('playerProfiles').doc(uid).get();
  return doc.data()?['bannerUrl'] as String? ?? '';
});

final playerDiscoverRadiusProvider = FutureProvider.autoDispose.family<int, String>((ref, uid) async {
  final doc = await FirebaseFirestore.instance.collection('playerProfiles').doc(uid).get();
  return doc.data()?['visibilityRadius'] as int? ?? 10;
});

final rankProvider = FutureProvider.autoDispose.family<int?, String>((ref, uid) async {
  final doc = await FirebaseFirestore.instance.collection('playerProfiles').doc(uid).get();
  final elo = doc.data()?['elo'] as int?;
  if (elo == null) return null;
  final rank = await FirebaseFirestore.instance
      .collection('playerProfiles')
      .where('elo', isGreaterThan: elo)
      .count()
      .get();
  return (rank.count ?? 0) + 1;
});

// --- Discovery feed -------------------------------------------------------

final searchCenterProvider = Provider<GeoPoint?>((ref) {
  final profile = ref.watch(myPlayerProfileProvider).value;
  return profile?.homeLocation;
});

final nearbyMatchupsProvider = StreamProvider<List<Matchup>>((ref) {
  final repo = ref.watch(matchupRepositoryProvider);
  final center = ref.watch(searchCenterProvider);
  final uid = ref.watch(currentUserIdProvider);
  return repo.nearbyMatchups(center: center, radiusKm: 250, excludeUserId: uid);
});

final matchupFromIdProvider = FutureProvider.autoDispose.family<Matchup, String>((ref, uid) async {
  final snap = await FirebaseFirestore.instance.collection('playerProfiles').doc(uid).get();
  return Matchup.fromJson({...snap.data()!, 'id': snap.id, 'distanceKm': 100});
});

typedef SString = (String, String);

class MatchOpponent {
  final MatchDoc match;
  final Matchup matchup;

  factory MatchOpponent.dummy() {
    return MatchOpponent(match: MatchDoc.dummy(), matchup: Matchup.dummy());
  }

  MatchOpponent({required this.match, required this.matchup});
}

final matchAndMatchupProvider = FutureProvider.autoDispose.family<MatchOpponent, SString>((ref, SString param) async {
  final String matchId;
  final String uid;
  (matchId, uid) = param;

  final matchDoc = await FirebaseFirestore.instance.collection('matches').doc(matchId).get();
  final match = MatchDoc.fromJson({...matchDoc.data()!, 'id': matchId});

  final opponentUid = match.otherParticipant(uid);

  final opponentDoc = await FirebaseFirestore.instance.collection('playerProfiles').doc(opponentUid).get();
  final opponent = Matchup.fromJson({...opponentDoc.data()!, 'id': opponentUid, 'distanceKm': 100});

  return MatchOpponent(match: match, matchup: opponent);
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

final chatProvider = StreamProvider.autoDispose.family<Chat, String>((ref, chatId) {
  final repo = ref.watch(matchRepositoryProvider);
  return repo.watchChat(chatId);
});

final matchRequestProvider = StreamProvider.autoDispose.family<MatchRequestDoc, String>((ref, requestId) {
  final repo = ref.watch(matchRepositoryProvider);
  return repo.watchMatchRequest(requestId);
});

final chatMessagesProvider = StreamProvider.autoDispose.family<List<ChatMessage>, String>((ref, chatId) {
  final repo = ref.watch(matchRepositoryProvider);
  return repo.watchMessages(chatId);
});

final matchProvider = StreamProvider.autoDispose.family<MatchDoc, String>((ref, matchId) {
  final repo = ref.watch(matchRepositoryProvider);
  return repo.watchMatch(matchId);
});

final lockedMatchesProvider = StreamProvider<List<MatchDoc>?>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  final repo = ref.watch(matchRepositoryProvider);
  return repo.watchLockedMatches(uid);
});
