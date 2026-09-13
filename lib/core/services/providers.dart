import 'dart:developer' show log;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hooper/features/auth/providers/auth_state_provider.dart';
import 'package:hooper/features/chat/data/chat.dart';
import 'package:hooper/features/chat/data/chat_message.dart';
import 'package:hooper/features/leaderboard/data/leaderboard_repo.dart';
import 'package:hooper/features/profile/data/elo_history.dart';
import 'package:hooper/features/profile/data/player_profile.dart';
import 'package:hooper/features/profile/data/preferences_repo.dart';
import 'package:hooper/features/profile/data/profile_repo.dart';
import 'package:hooper/features/profile/data/user_preferences.dart';
import 'package:hooper/features/requests/data/match_request_doc.dart';
import 'package:screen_corner_radius/screen_corner_radius.dart';

import '../../features/discovery/data/matchup.dart';
import '../../features/discovery/data/matchups_repo.dart';
import '../../features/matches/data/match_doc.dart';
import '../../features/matches/data/match_repo.dart';

typedef SString = (String, String);

// --- UI Data ----------------------------------------------------

final cornerRadiusProvider = FutureProvider<double>((ref) async {
  final rad = await ScreenCornerRadius.get();
  return rad?.bottomRight ?? 20;
});

final mapStyleProvider = FutureProvider<String>((ref) async {
  return await rootBundle.loadString('assets/map_style.json');
});

final backgroundImageProvider = Provider<ImageProvider>((ref) {
  return AssetImage('assets/img/blur_img.png');
});

// --- User Data --------------------------------------------------------

final profileExistsProvider = StreamProvider.autoDispose.family<bool, String>((
  ref,
  uid,
) {
  return FirebaseFirestore.instance
      .collection('playerProfiles')
      .doc(uid)
      .snapshots()
      .map((snap) => snap.exists);
});

final isNameTakenProvider = StreamProvider.autoDispose.family<bool, String>((
  ref,
  name,
) {
  return FirebaseFirestore.instance
      .collection('usernames')
      .doc(name)
      .snapshots()
      .map((snap) => snap.exists);
});

final completedMatchesProvider = FutureProvider.family<List<String>, String>((
  ref,
  uid,
) async {
  final x = await FirebaseFirestore.instance
      .collection('playerProfiles')
      .doc(uid)
      .get();
  return (x.data()?['completedMatches'] as List?)?.cast<String>() ?? [];
});

// (String, String) => (chatId, userId)
final lastMessageIdRead = FutureProvider.autoDispose.family<String?, SString>((
  ref,
  data,
) async {
  final chatId = data.$1;
  final userId = data.$2;
  final chat = await FirebaseFirestore.instance
      .collection('chats')
      .doc(chatId)
      .get();
  final map = (chat.data()?['lastMessageRead'] as Map?)?.cast<String, String>();
  return map?[userId];
});

// --- Geohash Related ----------------------------------------------------

final myLocationProvider = FutureProvider<Position>((ref) async {
  return await Geolocator.getCurrentPosition();
});

// --- Repositories -------------------------------------------------------

final matchupRepositoryProvider = Provider<FirestoreMatchupRepository>(
  (ref) => FirestoreMatchupRepository(),
);

final matchRepositoryProvider = Provider<FirestoreMatchRepository>(
  (ref) => FirestoreMatchRepository(),
);

final playerProfileRepositoryProvider =
    Provider<FirestorePlayerProfileRepository>(
      (ref) => FirestorePlayerProfileRepository(),
    );

final preferencesRepoProvider = Provider<FirestorePreferencesRepository>(
  (ref) => FirestorePreferencesRepository(),
);

final leaderboardRepoProvider = Provider<FirestoreLeaderboardRepository>(
  (ref) => FirestoreLeaderboardRepository(),
);

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

// Recent ELO history for any uid, not just the current user — matches (and
// therefore their rating deltas) are visible to any signed-in user per the
// firestore rules, so this works from anyone's profile.
final eloHistoryProvider = StreamProvider.autoDispose
    .family<List<EloHistoryEntry>, String>((ref, uid) {
      return FirebaseFirestore.instance
          .collection('playerProfiles')
          .doc(uid)
          .collection('eloHistory')
          .orderBy('timestamp', descending: true)
          .limit(20)
          .snapshots()
          .map(
            (snap) => snap.docs
                .map((d) => EloHistoryEntry.fromJson(d.data()))
                .toList(),
          );
    });

// Shared per-uid document fetch: playerDisplayNameProvider/playerPhotoUrlProvider/
// playerBannerUrlProvider/playerEloProvider/playerDiscoverRadiusProvider/rankProvider
// all used to issue their own independent `.get()` for the same uid — e.g. a chat
// list row watching both display name and photo would hit Firestore twice for the
// same doc. Routing them all through this one cached fetch means Riverpod dedupes
// concurrent/repeated reads of the same uid into a single round-trip.
final _playerProfileDocProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, uid) async {
      final doc = await FirebaseFirestore.instance
          .collection('playerProfiles')
          .doc(uid)
          .get();
      return doc.data();
    });

final playerDisplayNameProvider = FutureProvider.family<String, String>((
  ref,
  uid,
) async {
  final data = await ref.watch(_playerProfileDocProvider(uid).future);
  return data?['displayName'] as String? ?? 'Player';
});

final playerPhotoUrlProvider = FutureProvider.family<String, String>((
  ref,
  uid,
) async {
  final data = await ref.watch(_playerProfileDocProvider(uid).future);
  return data?['photoUrl'] as String? ?? '';
});

final playerBannerUrlProvider = FutureProvider.autoDispose
    .family<String, String>((ref, uid) async {
      final data = await ref.watch(_playerProfileDocProvider(uid).future);
      return data?['bannerUrl'] as String? ?? '';
    });

final playerEloProvider = FutureProvider.autoDispose.family<int, String>((
  ref,
  uid,
) async {
  final data = await ref.watch(_playerProfileDocProvider(uid).future);
  return data?['elo'] as int? ?? 0;
});

final imageProviderFamily = Provider.family<ImageProvider, String>((
  ref,
  imageUrl,
) {
  return CachedNetworkImageProvider(imageUrl);
});

final playerDiscoverRadiusProvider = FutureProvider.autoDispose
    .family<int, String>((ref, uid) async {
      final data = await ref.watch(_playerProfileDocProvider(uid).future);
      return data?['visibilityRadius'] as int? ?? 10;
    });

final rankProvider = FutureProvider.family<(int, int), String>((
  ref,
  uid,
) async {
  final data = await ref.watch(_playerProfileDocProvider(uid).future);
  final elo = data?['elo'] as int?;
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
    return repo.nearbyMatchups(
      center: center,
      radiusKm: 250,
      excludeUserId: uid,
    );
  } catch (e) {
    log(e.toString());
    return Stream.value([]);
  }
});

final matchupFromIdProvider = FutureProvider.autoDispose
    .family<Matchup, String>((ref, uid) async {
      if (uid == '') return Matchup.dummy();
      final data = await ref.watch(_playerProfileDocProvider(uid).future);
      return Matchup.fromJson({...data!, 'id': uid, 'distanceKm': 100});
    });

class MatchOpponent {
  final MatchDoc match;
  final Matchup matchup;

  factory MatchOpponent.dummy() {
    return MatchOpponent(match: MatchDoc.dummy(), matchup: Matchup.dummy());
  }

  MatchOpponent({required this.match, required this.matchup});
}

final matchAndMatchupProvider = FutureProvider.autoDispose
    .family<MatchOpponent, SString>((ref, SString param) async {
      final String matchId;
      final String uid;
      (matchId, uid) = param;

      final matchDoc = await FirebaseFirestore.instance
          .collection('matches')
          .doc(matchId)
          .get();
      final match = MatchDoc.fromJson({...matchDoc.data()!, 'id': matchId});

      final opponentUid = match.otherParticipant(uid);

      final opponentDoc = await FirebaseFirestore.instance
          .collection('playerProfiles')
          .doc(opponentUid)
          .get();
      final opponent = Matchup.fromJson({
        ...opponentDoc.data()!,
        'id': opponentUid,
        'distanceKm': 100,
      });

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

final chatProvider = StreamProvider.autoDispose.family<Chat, String>((
  ref,
  chatId,
) {
  final repo = ref.watch(matchRepositoryProvider);
  return repo.watchChat(chatId);
});

final matchRequestProvider = StreamProvider.autoDispose
    .family<MatchRequestDoc, String>((ref, requestId) {
      final repo = ref.watch(matchRepositoryProvider);
      return repo.watchMatchRequest(requestId);
    });

final chatMessagesProvider = StreamProvider.autoDispose
    .family<List<ChatMessage>, String>((ref, chatId) {
      final repo = ref.watch(matchRepositoryProvider);
      return repo.watchMessages(chatId);
    });

final matchProvider = StreamProvider.autoDispose.family<MatchDoc, String>((
  ref,
  matchId,
) {
  final repo = ref.watch(matchRepositoryProvider);
  return repo.watchMatch(matchId);
});

final lockedMatchesProvider = StreamProvider<List<MatchDoc>?>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  final repo = ref.watch(matchRepositoryProvider);
  return repo.watchLockedMatches(uid);
});

// Empty string (not a thrown error) when signed out, so widgets still mid-
// teardown right after sign-out (before AuthGate swaps them out) don't crash
// with a ProviderException — they read a harmless '' for one frame instead.
final currentUserIdProvider = Provider<String>((ref) {
  final user = ref.watch(authStateProvider).value;
  return user?.uid ?? '';
});
