import 'dart:async';
import 'dart:developer' show log;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooper/core/services/providers.dart';
import 'package:hooper/core/widgets/blurred_container.dart';
import 'package:hooper/core/widgets/dark_buttons.dart';
import 'package:hooper/features/matches/data/match_doc.dart';
import 'package:hooper/features/matches/presentation/current_playing_screen.dart';
import 'package:hooper/app/home_screen.dart';
import 'package:hooper/core/widgets/loading_screen_widget.dart';

const _lockCountdownSeconds = 30;

class LockGate extends ConsumerStatefulWidget {
  const LockGate({super.key});

  @override
  ConsumerState<LockGate> createState() => _LockGateState();
}

class _LockGateState extends ConsumerState<LockGate> {
  Timer? _timer;
  String? _timerTargetId;
  final Set<String> _startedMatchIds = {};
  String? _lastRoutedMatchId;

  // Countdown shown before actually yanking the user back to the root route
  // — without this, a match becoming due would silently pop whatever screen
  // (chat, an open form, etc.) the user was mid-task on.
  String? _pendingMatchId;
  Timer? _countdownTimer;
  final ValueNotifier<int> _secondsRemaining = ValueNotifier(
    _lockCountdownSeconds,
  );
  OverlayEntry? _overlayEntry;

  bool _shouldScore(MatchStatus status) =>
      status == MatchStatus.scheduled ||
      status == MatchStatus.inProgress ||
      status == MatchStatus.awaitingConfirmation ||
      status == MatchStatus.disputed;

  @override
  void dispose() {
    _timer?.cancel();
    _countdownTimer?.cancel();
    _overlayEntry?.remove();
    _secondsRemaining.dispose();
    super.dispose();
  }

  void _beginCountdown(String matchId) {
    if (_pendingMatchId == matchId) return;
    _cancelCountdown();
    _pendingMatchId = matchId;
    _secondsRemaining.value = _lockCountdownSeconds;

    final overlay = Overlay.of(context, rootOverlay: true);
    _overlayEntry = OverlayEntry(
      builder: (_) => _MatchStartingBanner(
        secondsRemaining: _secondsRemaining,
        onJumpIn: () => _finishCountdown(matchId),
      ),
    );
    overlay.insert(_overlayEntry!);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final next = _secondsRemaining.value - 1;
      if (next <= 0) {
        _finishCountdown(matchId);
      } else {
        _secondsRemaining.value = next;
      }
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _overlayEntry?.remove();
    _overlayEntry = null;
    _pendingMatchId = null;
  }

  void _finishCountdown(String matchId) {
    _cancelCountdown();
    _lastRoutedMatchId = matchId;
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final lockedMatches = ref.watch(lockedMatchesProvider);
    return lockedMatches.when(
      data: (data) {
        if (data == null || data.isEmpty) {
          _lastRoutedMatchId = null;
          if (_pendingMatchId != null) _cancelCountdown();
          return const HomePage();
        }

        final sorted = [...data]
          ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));

        MatchDoc? dueMatch;
        for (final doc in sorted) {
          if (_shouldScore(doc.status) && !doc.scheduledTime.isAfter(.now())) {
            dueMatch = doc;
            break;
          }
        }

        if (dueMatch != null) {
          final matchId = dueMatch.id;
          if (dueMatch.status == MatchStatus.scheduled &&
              _startedMatchIds.add(matchId)) {
            ref.read(matchRepositoryProvider).startMatch(matchId);
          }
          // Warn the user (even if they're deep in a pushed screen, e.g. a
          // chat) with a countdown before forcing them back to this route —
          // otherwise they'd be yanked out of whatever they were doing with
          // zero notice the moment a match becomes due.
          if (_lastRoutedMatchId != matchId && _pendingMatchId != matchId) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _beginCountdown(matchId);
            });
          }
          return CurrentlyPlayingScreen(matchId: matchId);
        }

        // The match that was pending a countdown is no longer due (e.g. it
        // got cancelled) — don't force a pop for something that isn't
        // starting anymore.
        if (_pendingMatchId != null) _cancelCountdown();
        _lastRoutedMatchId = null;

        final upcoming = sorted.where(
          (d) => _shouldScore(d.status) && d.scheduledTime.isAfter(.now()),
        );
        if (upcoming.isNotEmpty) {
          final next = upcoming.first;
          if (_timerTargetId != next.id) {
            _timer?.cancel();
            _timerTargetId = next.id;
            _timer = Timer(
              next.scheduledTime.difference(.now()),
              () => ref.invalidate(lockedMatchesProvider),
            );
          }
        } else {
          _timer?.cancel();
          _timerTargetId = null;
        }

        if (upcoming.isNotEmpty && (_timer == null || !_timer!.isActive)) {
          _timer = Timer(
            upcoming.first.scheduledTime.difference(.now()),
            () => ref.invalidate(lockedMatchesProvider),
          );
        }

        return const HomePage();
      },
      error: (error, stackTrace) {
        log(error.toString());
        log(stackTrace.toString());
        return const Scaffold(
          body: Center(child: Text('Something went wrong.')),
        );
      },
      loading: () => const SplashScreen(),
    );
  }
}

class _MatchStartingBanner extends StatelessWidget {
  const _MatchStartingBanner({
    required this.secondsRemaining,
    required this.onJumpIn,
  });

  final ValueNotifier<int> secondsRemaining;
  final VoidCallback onJumpIn;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 110,
      child: SafeArea(
        child: Material(
          type: .transparency,
          child: BlurredContainer(
            elevation: 2,
            radius: 24,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.sports_basketball_rounded),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ValueListenableBuilder<int>(
                      valueListenable: secondsRemaining,
                      builder: (context, seconds, _) => Text(
                        'Match starting in ${seconds}s',
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: .w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DarkFilledButton(
                    onPressed: onJumpIn,
                    shadow: false,
                    child: const Text('Jump in'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
