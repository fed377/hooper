import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooper/core/widgets/loading_screen_widget.dart';
import 'package:hooper/features/matches/data/match_repo.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../core/services/providers.dart';
import '../data/match_doc.dart';

class CurrentlyPlayingScreen extends ConsumerStatefulWidget {
  final String matchId;
  const CurrentlyPlayingScreen({super.key, required this.matchId});

  @override
  ConsumerState<CurrentlyPlayingScreen> createState() => _CurrentlyPlayingScreenState();
}

class _CurrentlyPlayingScreenState extends ConsumerState<CurrentlyPlayingScreen> {
  int _myScore = 11;
  int _opponentScore = 7;
  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(matchRepositoryProvider)
          .submitScore(matchId: widget.matchId, myScore: _myScore, opponentScore: _opponentScore);
    } on MatchActionException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref, MatchDoc match, {abandon = false}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${abandon ? "Abandon" : "Cancel"} this match?'),
        content: Row(children: [Text("This can't be undone, you'll both need to reschedule. ")]),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Back')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('${abandon ? "Abandon" : "Cancel"}  match'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(matchRepositoryProvider).cancelMatch(match.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Match cancelled.')));
      }
    } on MatchActionException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUserIdProvider);
    final matchAsync = ref.watch(matchProvider(widget.matchId));

    return Scaffold(
      appBar: AppBar(title: const Text('Match in progress'), automaticallyImplyLeading: false),
      body: matchAsync.when(
        loading: () => SplashScreen(),
        error: (err, _) => Center(
          child: Padding(padding: const EdgeInsets.all(24), child: Text('Could not load this match: $err')),
        ),
        data: (match) {
          if ((match.appearedIds ?? []).length >= 2) {
            return _buildBody(match, uid);
          } else {
            return Center(
              child: Column(
                mainAxisSize: .min,
                children: [
                  Text("Your opponent hasn't shown up. \nPlease wait for them to show up\nor cancel"),
                  const SizedBox(height: 8),
                  FilledButton(onPressed: () => _confirmCancel(context, ref, match), child: Text("Cancel Match")),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildBody(MatchDoc match, String uid) {
    final otherId = match.otherParticipant(uid);
    final nameAsync = ref.watch(playerDisplayNameProvider(otherId));
    final mySide = match.mySide(uid);

    if (mySide == null) {
      return const Center(child: Text("You're not part of this match."));
    }

    if (match.status == MatchStatus.confirmed) {
      return const Center(child: Text('This match is confirmed and is over.'));
    }
    if (match.status == MatchStatus.cancelled) {
      return const Center(child: Text('This match was cancelled.'));
    }
    if (match.status == MatchStatus.scheduled) {
      return const Center(
        child: Column(
          mainAxisSize: .min,
          children: [CircularProgressIndicator(), SizedBox(height: 12), Text('Starting your match…')],
        ),
      );
    }

    final otherSide = mySide == 'A' ? 'B' : 'A';
    final theirReport = match.reportedBy(otherSide); // (theirScore, myScoreAccordingToThem)
    final myReport = match.reportedBy(mySide); // (myScore, theirScoreAccordingToMe)
    final iHaveSubmitted = myReport != null;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'vs ${nameAsync.value ?? '…'}',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(match.court, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
        const SizedBox(height: 20),

        if (match.status == MatchStatus.disputed)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.errorContainer, borderRadius: .circular(12)),
            child: const Text("Your scores didn't match. Double-check and submit again.", textAlign: TextAlign.center),
          ),

        _SubmissionCard(
          title: '${nameAsync.value ?? 'Opponent'}\'s report',
          report: theirReport,
          waitingText: 'Waiting for them to submit a score',
        ),
        const SizedBox(height: 12),

        if (iHaveSubmitted && match.status != MatchStatus.disputed) ...[
          _SubmissionCard(title: 'Your report', report: myReport, waitingText: ''),
          const SizedBox(height: 16),
          const Center(
            child: Column(
              mainAxisSize: .min,
              children: [CircularProgressIndicator(), SizedBox(height: 12), Text('Waiting for confirmation…')],
            ),
          ),
        ] else
          _buildEntryForm(),
        if (match.scoreSubmissions?.isEmpty ?? true) ...[
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () => _confirmCancel(context, ref, match, abandon: true),
            child: Text("Abandon Match"),
          ),
        ],
      ],
    );
  }

  Widget _buildEntryForm() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: .center,
          children: [
            _ScoreStepper(label: 'You', value: _myScore, onChanged: (v) => setState(() => _myScore = v)),
            const SizedBox(width: 24),
            Text('–', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(width: 24),
            _ScoreStepper(label: 'Them', value: _opponentScore, onChanged: (v) => setState(() => _opponentScore = v)),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Enter the final score exactly as played.',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 16),
        Skeletonizer(
          enabled: _submitting,
          child: FilledButton(onPressed: _submitting ? null : _submit, child: const Text('Submit score')),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  final String title;
  final (int, int)? report; // (theirScore-from-their-view, yourScore-from-their-view)
  final String waitingText;

  const _SubmissionCard({required this.title, required this.report, required this.waitingText});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHigh, borderRadius: .circular(12)),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          if (report == null)
            Text(waitingText, style: Theme.of(context).textTheme.bodyMedium)
          else
            Text('${report!.$1} – ${report!.$2}', style: Theme.of(context).textTheme.headlineSmall),
        ],
      ),
    );
  }
}

class _ScoreStepper extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _ScoreStepper({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => onChanged(value + 1)),
        Text('$value', style: Theme.of(context).textTheme.headlineMedium),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: value > 0 ? () => onChanged(value - 1) : null,
        ),
      ],
    );
  }
}
