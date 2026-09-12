import 'dart:developer' show log;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooper/core/services/providers.dart';
import 'package:hooper/core/utils/utils.dart';
import 'package:hooper/core/widgets/background_image.dart';
import 'package:hooper/core/widgets/blurred_container.dart';
import 'package:hooper/core/widgets/skeleton_widget.dart';
import 'package:hooper/features/discovery/data/matchup.dart';
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
          BackgroundImage(),
          SizedBox.expand(
            child: Column(
              mainAxisSize: .min,
              children: [
                AppBar(
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  actionsPadding: EdgeInsets.only(right: 12),
                  title: Text("Leaderboard"),
                  actions: [
                    SkeletonWidget<(int, int)>(
                      val: ref.watch(rankProvider(ref.watch(currentUserIdProvider))),
                      dummyData: (-1, -1),
                      builder: ((int, int) values) {
                        int upper = values.$1;
                        int lower = values.$2;
                        return Chip(
                          shape: RoundedSuperellipseBorder(borderRadius: .circular(12)),
                          label: Text("Your Rank: ${upper + 1} - $lower"),
                        );
                      },
                    ),
                  ],
                ),
                Padding(
                  padding: .all(16),
                  child: BlurredContainer(
                    elevation: 2, 
                    height: MediaQuery.sizeOf(context).height / 4,
                    child: SizedBox(
                      width: double.infinity,
                      child: Row(
                        children: [
                          ?ref
                              .watch(playerEloProvider(ref.read(currentUserIdProvider)))
                              .when(
                                data: (int data) {
                                  final progress = eloProgress(data);
                                  if (progress == null) return null;
                                  return Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Container(
                                        padding: .all(16),
                                        decoration: ShapeDecoration(
                                          shape: RoundedSuperellipseBorder(borderRadius: .circular(20)),
                                          color: HooprColors.instance.darkenColor,
                                        ),
                                        child: LinearProgressIndicator(
                                          value: (data - progress.$2) / (progress.$3 - progress.$2),
                                          color: const Color.fromARGB(255, 0, 0, 0),
                                          backgroundColor: HooprColors.instance.darkenColor,
                                          minHeight: 8,
                                          borderRadius: .circular(10),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                error: (Object error, StackTrace stackTrace) {
                                  return null;
                                },
                                loading: () {
                                  return Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Container(
                                        padding: .all(16),
                                        decoration: ShapeDecoration(
                                          shape: RoundedSuperellipseBorder(borderRadius: .circular(20)),
                                          color: HooprColors.instance.darkenColor,
                                        ),
                                        child: LinearProgressIndicator(
                                          color: const Color.fromARGB(255, 0, 0, 0),
                                          backgroundColor: HooprColors.instance.darkenColor,
                                          minHeight: 8,
                                          borderRadius: .circular(10),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
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

    return RefreshIndicator(
      onRefresh: _loadFirstPage,
      child: ListView.separated(
        controller: _controller,
        itemCount: _entries.length + 1,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index == _entries.length) {
            return _buildFooter();
          }
          final rank = index + 1;
          final m = _entries[index];
          return ListTile(
            leading: Row(
              mainAxisSize: .min,
              children: [
                Text(rank.toString(), style: TextTheme.of(context).bodyLarge),
                const SizedBox(width: 14),
                m.photoUrl == null
                    ? CircleAvatar(child: Text(m.displayName[0]))
                    : CircleAvatar(foregroundImage: CachedNetworkImageProvider(m.photoUrl!)),
              ],
            ),
            title: Text(m.displayName),
            subtitle: Text(m.elo.toString().toUpperCase()),
            onTap: m.id == ''
                ? null
                : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MatchupViewScreen(matchup: m))),
          );
        },
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
