import 'dart:async';
import 'dart:developer' show log;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooper/data/providers.dart';
import 'package:hooper/models/match_doc.dart';
import 'package:hooper/screens/current_playing_screen.dart';
import 'package:hooper/screens/home_screen.dart';
import 'package:hooper/core/widgets/loading_screen_widget.dart';

class LockGate extends ConsumerStatefulWidget {
  const LockGate({super.key});

  @override
  @override
  ConsumerState<LockGate> createState() => _LockGateState();
}

class _LockGateState extends ConsumerState<LockGate> {
  Timer? _timer;
  String? _timerTargetId;
  final Set<String> _startedMatchIds = {};

  bool _shouldScore(MatchStatus status) =>
      status == MatchStatus.scheduled ||
      status == MatchStatus.inProgress ||
      status == MatchStatus.awaitingConfirmation ||
      status == MatchStatus.disputed;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lockedMatches = ref.watch(lockedMatchesProvider);
    return lockedMatches.when(
      data: (data) {
        if (data == null || data.isEmpty) return const HomePage();

        final sorted = [...data]..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));

        MatchDoc? dueMatch;
        for (final doc in sorted) {
          if (_shouldScore(doc.status) && !doc.scheduledTime.isAfter(.now())) {
            dueMatch = doc;
            break;
          }
        }

        if (dueMatch != null) {
          if (dueMatch.status == MatchStatus.scheduled && _startedMatchIds.add(dueMatch.id)) {
            ref.read(matchRepositoryProvider).startMatch(dueMatch.id);
          }
          return CurrentlyPlayingScreen(matchId: dueMatch.id);
        }

        final upcoming = sorted.where((d) => _shouldScore(d.status) && d.scheduledTime.isAfter(.now()));
        if (upcoming.isNotEmpty) {
          final next = upcoming.first;
          if (_timerTargetId != next.id) {
            _timer?.cancel();
            _timerTargetId = next.id;
            _timer = Timer(next.scheduledTime.difference(.now()), () => ref.invalidate(lockedMatchesProvider));
          }
        } else {
          _timer?.cancel();
          _timerTargetId = null;
        }

        if (upcoming.isNotEmpty && (_timer == null || !_timer!.isActive)) {
          _timer = Timer(upcoming.first.scheduledTime.difference(.now()), () => ref.invalidate(lockedMatchesProvider));
        }

        return const HomePage();
      },
      error: (error, stackTrace) {
        log(error.toString());
        log(stackTrace.toString());
        return const Scaffold(body: Center(child: Text('Something went wrong.')));
      },
      loading: () => const SplashScreen(),
    );
  }
}
