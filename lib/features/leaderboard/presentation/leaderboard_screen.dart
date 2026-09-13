import 'dart:developer' show log;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooper/core/services/providers.dart';
import 'package:hooper/core/utils/utils.dart';
import 'package:hooper/core/widgets/animated_blurred_picker.dart';
import 'package:hooper/core/widgets/background_image.dart';
import 'package:hooper/core/widgets/blurred_container.dart';
import 'package:hooper/core/widgets/elo_rank_chip.dart';
import 'package:hooper/core/widgets/skeleton_widget.dart';
import 'package:hooper/features/discovery/data/matchup.dart';
import 'package:hooper/features/profile/data/player_profile.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../requests/presentation/matchup_view_screen.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  final _controller = ScrollController();
  final List<Matchup> _entries = [];
  DocumentSnapshot? _cursor;
  bool _hasMore = true;
  bool _firstLoad = true;
  bool _loading = false;
  String? _error;

  int _tab = 0;
  List<Matchup> _nearMeEntries = [];
  int? _nearMeStartRank;
  bool _nearMeLoading = false;
  bool _nearMeLoaded = false;
  String? _nearMeError;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loading) return;
    final remaining = _controller.position.maxScrollExtent - _controller.position.pixels;
    if (remaining < 400.0) {
      _loadNextPage();
    }
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _firstLoad = true;
      _error = null;
    });
    try {
      final repo = ref.read(leaderboardRepoProvider);
      final page = await repo.fetchPage(pageSize: 20);
      if (!mounted) return;
      setState(() {
        _entries
          ..clear()
          ..addAll(page.entries);
        _cursor = page.lastDocument;
        _hasMore = page.hasMore;
      });
    } catch (e, trace) {
      log(trace.toString());
      if (!mounted) return;
      setState(() => _error = 'Could not load leaderboard: $e');
    } finally {
      if (mounted) setState(() => _firstLoad = false);
    }
  }

  Future<void> _loadNextPage() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(leaderboardRepoProvider);
      final page = await repo.fetchPage(startAfter: _cursor, pageSize: 20);
      if (!mounted) return;
      setState(() {
        _entries.addAll(page.entries);
        _cursor = page.lastDocument;
        _hasMore = page.hasMore;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not load more: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onTabChanged(int index) {
    setState(() => _tab = index);
    if (index == 1 && !_nearMeLoaded) {
      _loadAroundMe();
    }
  }

  Future<void> _loadAroundMe() async {
    setState(() {
      _nearMeLoading = true;
      _nearMeError = null;
    });
    try {
      final profile = await ref.read(myPlayerProfileProvider.future);
      final repo = ref.read(leaderboardRepoProvider);
      final page = await repo.fetchAroundMe(myElo: profile.elo);
      if (!mounted) return;
      setState(() {
        _nearMeEntries = page.entries;
        _nearMeStartRank = page.startRank;
        _nearMeLoaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _nearMeError = 'Could not load rankings: $e');
    } finally {
      if (mounted) setState(() => _nearMeLoading = false);
    }
  }

  (String, int, int)? eloProgress(int elo) {
    if (elo >= 1900) return null;
    if (elo >= 1600) return ('Elite', 1600, 1900);
    if (elo >= 1300) return ('Pro', 1300, 1600);
    if (elo >= 1000) return ('Baller', 1000, 1300);
    return ('Rising', 0, 1000);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          if (HooprTheme.instance.glass) BackgroundImage(),
          SizedBox.expand(
            child: Column(
              mainAxisSize: .min,
              children: [
                AppBar(
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  title: Text("Leaderboard"),
                ),
                Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), child: _buildStatsCard()),
                Expanded(
                  child: Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 88), child: _buildLeaderboardPanel()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    final uid = ref.watch(currentUserIdProvider);
    return BlurredContainer(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SkeletonWidget<PlayerProfile>(
          val: ref.watch(myPlayerProfileProvider),
          dummyData: PlayerProfile.dummy(),
          builder: (profile) => _buildStatsContent(profile, uid),
        ),
      ),
    );
  }

  Widget _buildStatsContent(PlayerProfile profile, String uid) {
    final textTheme = TextTheme.of(context);
    final tier = tierForElo(profile.elo);
    final progress = eloProgress(profile.elo);
    final rankAsync = ref.watch(rankProvider(uid));

    return Column(
      crossAxisAlignment: .start,
      mainAxisSize: .min,
      children: [
        Row(
          crossAxisAlignment: .start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                mainAxisSize: .min,
                children: [
                  Text('${profile.elo}', style: textTheme.headlineMedium?.copyWith(fontWeight: .bold)),
                  const SizedBox(height: 6),
                  EloRankChip(elo: profile.elo),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: .end,
              mainAxisSize: .min,
              children: [
                Text('RANK', style: textTheme.labelSmall?.copyWith(letterSpacing: 0.5)),
                const SizedBox(height: 4),
                rankAsync.maybeWhen(
                  data: (ranks) {
                    final (upper, lower) = ranks;
                    if (upper < 0) return const SizedBox();
                    final label = upper + 1 >= lower ? '#${upper + 1}' : '#${upper + 1}–$lower';
                    return Text(label, style: textTheme.titleLarge?.copyWith(fontWeight: .bold));
                  },
                  orElse: () => Text('—', style: textTheme.titleLarge?.copyWith(fontWeight: .bold)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (progress == null)
          Row(
            children: [
              const Icon(Icons.emoji_events_rounded, color: Colors.amber),
              const SizedBox(width: 8),
              Expanded(child: Text("You've reached ${tierLabel(tier)} — the highest tier!")),
            ],
          )
        else ...[
          Row(
            mainAxisAlignment: .spaceBetween,
            children: [
              Text('${progress.$3 - profile.elo} ELO to ${progress.$1}', style: textTheme.bodyMedium),
              Text('${profile.elo} / ${progress.$3}', style: textTheme.bodyMedium),
            ],
          ),
          const SizedBox(height: 6),
          ClipRSuperellipse(
            borderRadius: .circular(10),
            child: LinearProgressIndicator(
              value: (profile.elo - progress.$2) / (progress.$3 - progress.$2),
              color: Colors.black,
              backgroundColor: HooprTheme.instance.darkenColor,
              minHeight: 8,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLeaderboardPanel() {
    return BlurredContainer(
      elevation: 1,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: AnimatedBlurredPicker(
              includeBlurredContainer: false,
              radius: 18,
              height: 50,
              currItem: _tab.toDouble(),
              elements: const [Text('Global'), Text('Near Me')],
              onTap: _onTabChanged,
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return _tab == 0 ? _buildGlobalBody() : _buildNearMeBody();
  }

  Widget _buildGlobalBody() {
    if (_firstLoad) {
      return _buildSkeletons(10);
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _loadFirstPage, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_entries.isEmpty) {
      return const Center(child: Text('No players yet.'));
    }

    final myUid = ref.read(currentUserIdProvider);
    return RefreshIndicator(
      onRefresh: _loadFirstPage,
      child: ListView.builder(
        controller: _controller,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: _entries.length + 1,
        itemBuilder: (context, index) {
          if (index == _entries.length) {
            return _buildFooter();
          }
          final m = _entries[index];
          return _buildRow(m, index + 1, isMe: m.id == myUid);
        },
      ),
    );
  }

  Widget _buildNearMeBody() {
    if (_nearMeLoading && !_nearMeLoaded) {
      return _buildSkeletons(10);
    }
    if (_nearMeError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(_nearMeError!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _loadAroundMe, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_nearMeEntries.isEmpty) {
      return const Center(child: Text('No players yet.'));
    }

    final myUid = ref.read(currentUserIdProvider);
    final startRank = _nearMeStartRank ?? 1;
    return RefreshIndicator(
      onRefresh: _loadAroundMe,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: _nearMeEntries.length,
        itemBuilder: (context, index) {
          final m = _nearMeEntries[index];
          return _buildRow(m, startRank + index, isMe: m.id == myUid);
        },
      ),
    );
  }

  Widget _buildRow(Matchup m, int rank, {bool isMe = false}) {
    final textTheme = TextTheme.of(context);

    return ClipRSuperellipse(
      borderRadius: .circular(16),
      child: Material(
        color: isMe ? HooprTheme.instance.darkenColor : Colors.transparent,
        child: InkWell(
          onTap: m.id == ''
              ? null
              : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MatchupViewScreen(matchup: m))),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: Center(child: Text('$rank', style: textTheme.bodyLarge)),
                ),
                const SizedBox(width: 12),
                m.photoUrl == null
                    ? CircleAvatar(radius: 20, child: Text(m.displayName.isEmpty ? '?' : m.displayName[0]))
                    : CircleAvatar(
                        radius: 20,
                        foregroundImage: ResizeImage(CachedNetworkImageProvider(m.photoUrl!), width: 120),
                      ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    mainAxisSize: .min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              m.displayName,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.titleSmall?.copyWith(fontWeight: .bold),
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)),
                              child: const Text(
                                'YOU',
                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                      EloRankChip(elo: m.elo),
                    ],
                  ),
                ),
                Text('${m.elo}', style: textTheme.titleMedium?.copyWith(fontWeight: .bold)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletons(int count) {
    return Skeletonizer(
      child: ListView(
        children: List.generate(
          count,
          (_) => ListTile(
            leading: Row(
              mainAxisSize: .min,
              children: [
                Text("12", style: TextTheme.of(context).bodyLarge),
                const SizedBox(width: 14),
                CircleAvatar(child: Text("A")),
              ],
            ),
            title: Text(BoneMock.name),
            subtitle: Text("1234"),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    if (_loading) {
      return _buildSkeletons(6);
    }
    if (!_hasMore) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: Text("You've reached the end")),
      );
    }
    return const SizedBox(height: 40);
  }
}
