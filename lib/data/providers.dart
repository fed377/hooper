import 'dart:developer' show log;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooper/data/repos/firestore_leaderboard_repo.dart';
import 'package:hooper/data/repos/firestore_profiles_repo.dart';
import 'package:hooper/data/repos/leaderboard_repo.dart';
import 'package:hooper/data/repos/preferences_repo.dart';
import 'package:hooper/data/repos/profiles_repo.dart';
import 'package:hooper/models/chat.dart';
import 'package:hooper/models/chat_message.dart';
import 'package:hooper/models/match_request_doc.dart';
import 'package:hooper/models/player_profile.dart';
import 'package:hooper/models/user_preferences.dart';

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

final completedMatchesProvider = FutureProvider.autoDispose.family<List<String>, String>((ref, uid) async {
  final x = await FirebaseFirestore.instance.collection('playerProfiles').doc(uid).get();
  return (x.data()?['completedMatches'] as List?)?.cast<String>() ?? [];
});

// (String, String) => (chatId, userId)
final lastMessageIdRead = FutureProvider.autoDispose.family<String?, SString>((ref, data) async {
  final chatId = data.$1;
  final userId = data.$2;
  final chat = await FirebaseFirestore.instance.collection('chats').doc(chatId).get();
  final map = (chat.data()?['lastMessageRead'] as Map?)?.cast<String, String>();
  return map?[userId];
});

final myDateOfBirthProvider = StreamProvider.autoDispose.family<DateTime?, String>((ref, uid) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((snap) => (snap.data()?['dateOfBirth'] as Timestamp?)?.toDate());
});

// --- Repositories -------------------------------------------------------

final matchupRepositoryProvider = Provider<MatchupRepository>((ref) => FirestoreMatchupRepository());

final matchRepositoryProvider = Provider<MatchRepository>((ref) => FirestoreMatchRepository());

final playerProfileRepositoryProvider = Provider<PlayerProfileRepository>((ref) => FirestorePlayerProfileRepository());

final preferencesRepoProvider = Provider<FirestorePreferencesRepository>((ref) => FirestorePreferencesRepository());

final leaderboardRepoProvider = Provider<LeaderboardRepository>((ref) => FirestoreLeaderboardRepository());

// --- Preferences --------------------------------------------------------

final myPreferencesProvider = StreamProvider<UserPreference>((ref) {
  final repo = ref.watch(preferencesRepoProvider);
  final uid = ref.watch(currentUserIdProvider);
  return repo.watchMyPreferences(uid);
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

final playerBannerUrlProvider = FutureProvider.autoDispose.family<String, String>((ref, uid) async {
  final doc = await FirebaseFirestore.instance.collection('playerProfiles').doc(uid).get();
  return doc.data()?['bannerUrl'] as String? ?? '';
});

final playerDiscoverRadiusProvider = FutureProvider.autoDispose.family<int, String>((ref, uid) async {
  final doc = await FirebaseFirestore.instance.collection('playerProfiles').doc(uid).get();
  return doc.data()?['visibilityRadius'] as int? ?? 10;
});

final rankProvider = FutureProvider.family<(int, int), String>((ref, uid) async {
  final doc = await FirebaseFirestore.instance.collection('playerProfiles').doc(uid).get();
  final elo = doc.data()?['elo'] as int?;
  if (elo == null) return (-1, -1);
  final upperRank = await FirebaseFirestore.instance
      .collection('playerProfiles')
      .where('elo', isGreaterThan: elo)
      .count()
      .get();
  final lowerRank = await FirebaseFirestore.instance
      .collection('playerProfiles')
      .where('elo', isGreaterThan: elo - 1)
      .count()
      .get();
  final upper = upperRank.count ?? -1;
  final lower = lowerRank.count ?? -1;
  return (upper, lower);
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
  try {
    return repo.nearbyMatchups(center: center, radiusKm: 250, excludeUserId: uid);
  } catch (e) {
    log(e.toString());
    return Stream.value([]);
  }
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
