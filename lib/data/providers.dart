import 'dart:developer' show log;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hooper/data/repos/leaderboard_repo.dart';
import 'package:hooper/data/repos/profile_repo.dart';
import 'package:hooper/data/repos/preferences_repo.dart';
import 'package:hooper/features/auth/data/app_auth_state.dart';
import 'package:hooper/models/chat.dart';
import 'package:hooper/models/chat_message.dart';
import 'package:hooper/models/match_request_doc.dart';
import 'package:hooper/models/player_profile.dart';
import 'package:hooper/models/user_preferences.dart';
import 'package:screen_corner_radius/screen_corner_radius.dart';

import '../models/match_doc.dart';
import '../models/matchup.dart';
import 'repos/match_repo.dart';
import 'repos/matchups_repo.dart';

typedef SString = (String, String);

// --- UI Data ----------------------------------------------------

final cornerRadiusProvider = FutureProvider<double>((ref) async {
  final rad = await ScreenCornerRadius.get();
  return rad?.bottomRight ?? 20;
});

final mapStyleProvider = FutureProvider<String>((ref) async {
  return await rootBundle.loadString('assets/map_style.json');
});

// --- Auth -------------------------------------------------------------

final appAuthStateProvider = FutureProvider<AppAuthState>((ref) async {
  final user = await ref.watch(_authStateProvider.future);
  if (user == null) {
    return AppAuthState(status: AuthStatus.unauthenticated);
  }

  final isVerified = await ref.watch(_userVerifiedProvider.future);
  if (!isVerified) {
    return AppAuthState(status: AuthStatus.unverified, user: user);
  }

  final statusInfo = await ref.watch(_myAccountStatusProvider(user.uid).future);
  if (statusInfo.status != 'active') {
    return AppAuthState(
      status: AuthStatus.restricted,
      user: user,
      restrictionReason: statusInfo.reason,
      accountStatus: statusInfo.status,
    );
  }

  final profileExists = await ref.watch(profileExistsProvider(user.uid).future);
  if (!profileExists) {
    return AppAuthState(status: AuthStatus.needsProfileFill, user: user);
  }

  final birthDate = await ref.watch(_myDateOfBirthProvider(user.uid).future);
  if (birthDate == null) {
    return AppAuthState(status: AuthStatus.needsProfileFill, user: user);
  }

  return AppAuthState(status: AuthStatus.authenticated, user: user);
});

final _authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final currentUserIdProvider = Provider<String>((ref) {
  final user = ref.watch(_authStateProvider).value;
  if (user == null) {
    throw StateError('currentUserIdProvider read before sign-in.');
  }
  return user.uid;
});

final _userVerifiedProvider = FutureProvider<bool>((ref) async {
  User? user = FirebaseAuth.instance.currentUser;
  await user?.reload();
  return FirebaseAuth.instance.currentUser?.emailVerified ?? false;
});

class AccountStatusInfo({required var String status, required var String? reason});

final _myAccountStatusProvider = StreamProvider.family<AccountStatusInfo, String>((ref, uid) {
  return FirebaseFirestore.instance.collection('users').doc(uid).snapshots().map((snap) {
    final data = snap.data();
    return AccountStatusInfo(status: data?['status'] as String? ?? 'active', reason: data?['statusReason'] as String?);
  });
});

// --- User Data --------------------------------------------------------

final profileExistsProvider = StreamProvider.autoDispose.family<bool, String>((ref, uid) {
  return FirebaseFirestore.instance.collection('playerProfiles').doc(uid).snapshots().map((snap) => snap.exists);
});

final isNameTakenProvider = StreamProvider.autoDispose.family<bool, String>((ref, name) {
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

final _myDateOfBirthProvider = StreamProvider.autoDispose.family<DateTime?, String>((ref, uid) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((snap) => (snap.data()?['dateOfBirth'] as Timestamp?)?.toDate());
});

// --- Geohash Related ----------------------------------------------------

final myLocationProvider = FutureProvider<Position>((ref) async {
  return await Geolocator.getCurrentPosition();
});

// --- Repositories -------------------------------------------------------

final matchupRepositoryProvider = Provider<FirestoreMatchupRepository>((ref) => FirestoreMatchupRepository());

final matchRepositoryProvider = Provider<FirestoreMatchRepository>((ref) => FirestoreMatchRepository());

final playerProfileRepositoryProvider = Provider<FirestorePlayerProfileRepository>(
  (ref) => FirestorePlayerProfileRepository(),
);

final preferencesRepoProvider = Provider<FirestorePreferencesRepository>((ref) => FirestorePreferencesRepository());

final leaderboardRepoProvider = Provider<FirestoreLeaderboardRepository>((ref) => FirestoreLeaderboardRepository());

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
