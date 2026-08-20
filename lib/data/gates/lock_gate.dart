import 'dart:developer' show log;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooper/data/providers.dart';
import 'package:hooper/models/match_doc.dart';
import 'package:hooper/screens/current_playing_screen.dart';
import 'package:hooper/screens/home_screen.dart';

class LockGate extends ConsumerWidget {
  const LockGate({super.key});

  bool _shouldScore(MatchStatus status) =>
      status == MatchStatus.awaitingConfirmation || status == MatchStatus.inProgress || status == MatchStatus.scheduled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lockedMatches = ref.watch(lockedMatchesProvider);
    return lockedMatches.when(
      data: (List<MatchDoc>? data) {
        for (final MatchDoc doc in data ?? []) {
          if (_shouldScore(doc.status) && doc.scheduledTime.isBefore(DateTime.now())) {
            if (doc.status == MatchStatus.scheduled) {
              final repo = ref.watch(matchRepositoryProvider);
              repo.startMatch(doc.id);
            }
            return CurrentlyPlayingScreen(matchId: doc.id);
          }
        }
        return Center(child: const HomePage());
      },
      error: (Object error, StackTrace stackTrace) {
        log(error.toString());
        log(stackTrace.toString());
        return Text("error");
      },
      loading: () {
        return Text("Loading");
      },
    );
  }
}
