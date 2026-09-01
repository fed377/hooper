import 'dart:developer' show log;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooper/data/providers.dart';
import 'package:hooper/models/matchup.dart';
import 'package:hooper/core/widgets/skeleton_widget.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'matchup_view_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
      body: _buildBody(),
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
            mainAxisSize: .min,
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
