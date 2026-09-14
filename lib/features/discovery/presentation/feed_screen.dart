import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooper/core/widgets/blurred_container.dart';
import 'package:hooper/core/widgets/blurred_text_field.dart';
import 'package:hooper/core/widgets/dark_buttons.dart';
import 'package:hooper/core/widgets/skeleton_widget.dart';
import 'package:hooper/features/chat/data/chat.dart';
import 'package:hooper/features/chat/presentation/chat_screen.dart';
import 'package:hooper/features/discovery/data/matchup.dart';
import 'package:hooper/features/profile/data/player_profile.dart';
import 'package:hooper/features/requests/presentation/matchup_view_screen.dart';
import 'package:hooper/features/requests/presentation/propose_screen.dart';

import '../../../core/services/providers.dart';
import 'matchup_card.dart';

const _kMaxDiscoveryDistanceKm = 250.0;

class MatchupFeedScreen extends ConsumerStatefulWidget {
  const MatchupFeedScreen({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() {
    return MatchupFeedScreenState();
  }
}

class MatchupFeedScreenState extends ConsumerState<MatchupFeedScreen> {
  int _currIndex = 0;
  final _pageController = PageController();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  bool _searchExpanded = false;

  String _query = '';
  final Set<PlayerPosition> _positionFilter = {};
  final Set<Tier> _tierFilter = {};
  final Set<Gender> _genderFilter = {};
  double _maxDistanceKm = _kMaxDiscoveryDistanceKm;

  bool get _hasActiveFilters =>
      _positionFilter.isNotEmpty ||
      _tierFilter.isNotEmpty ||
      _genderFilter.isNotEmpty ||
      _maxDistanceKm < _kMaxDiscoveryDistanceKm;

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _expandSearch() {
    setState(() => _searchExpanded = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  void _collapseSearch() {
    _searchController.clear();
    _query = '';
    setState(() => _searchExpanded = false);
    _resetToTop();
  }

  List<Matchup> _applyFilters(List<Matchup> matchups) {
    final query = _query.trim().toLowerCase();
    return matchups.where((m) {
      if (query.isNotEmpty && !m.displayName.toLowerCase().contains(query)) {
        return false;
      }
      if (_positionFilter.isNotEmpty &&
          !_positionFilter.contains(playerPositionFromInt(m.position))) {
        return false;
      }
      if (_tierFilter.isNotEmpty && !_tierFilter.contains(m.tier)) return false;
      if (_genderFilter.isNotEmpty && !_genderFilter.contains(m.genderValue)) {
        return false;
      }
      if (m.distanceKm > _maxDistanceKm) return false;
      return true;
    }).toList();
  }

  // Search/filter changes can shrink the list out from under whatever page
  // the user was swiped to, so jump back to the top result rather than
  // risk an out-of-range index.
  void _resetToTop() {
    setState(() => _currIndex = 0);
    if (_pageController.hasClients) _pageController.jumpToPage(0);
  }

  void _clearFilters() {
    setState(() {
      _positionFilter.clear();
      _tierFilter.clear();
      _genderFilter.clear();
      _maxDistanceKm = _kMaxDiscoveryDistanceKm;
    });
    _resetToTop();
  }

  Future<void> _openFilterSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 8,
                bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: .min,
                crossAxisAlignment: .start,
                children: [
                  Text(
                    'Filters',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: .bold),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Position',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: PlayerPosition.values.map((p) {
                      final selected = _positionFilter.contains(p);
                      return FilterChip(
                        label: Text(playerPositionToString(p)),
                        selected: selected,
                        onSelected: (v) => setSheetState(
                          () => v
                              ? _positionFilter.add(p)
                              : _positionFilter.remove(p),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text('Gender', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: Gender.values.map((g) {
                      final selected = _genderFilter.contains(g);
                      return FilterChip(
                        label: Text(genderToString(g)),
                        selected: selected,
                        onSelected: (v) => setSheetState(
                          () => v
                              ? _genderFilter.add(g)
                              : _genderFilter.remove(g),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text('Tier', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: Tier.values.map((t) {
                      final selected = _tierFilter.contains(t);
                      return FilterChip(
                        label: Text(tierLabel(t)),
                        selected: selected,
                        onSelected: (v) => setSheetState(
                          () => v ? _tierFilter.add(t) : _tierFilter.remove(t),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Max distance: ${_maxDistanceKm.round()} km',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Slider(
                    value: _maxDistanceKm,
                    min: 5,
                    max: _kMaxDiscoveryDistanceKm,
                    divisions: 49,
                    label: '${_maxDistanceKm.round()} km',
                    onChanged: (v) => setSheetState(() => _maxDistanceKm = v),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setSheetState(() {
                            _positionFilter.clear();
                            _tierFilter.clear();
                            _genderFilter.clear();
                            _maxDistanceKm = _kMaxDiscoveryDistanceKm;
                          }),
                          child: const Text('Clear all'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Apply'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    _resetToTop();
  }

  Widget _buildSearchBar() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const collapsedWidth = 48.0;
            const buttonGap = 8.0;
            const filterButtonWidth = 48.0;
            final expandedWidth =
                constraints.maxWidth - filterButtonWidth - buttonGap;

            return Row(
              children: [
                AnimatedContainer(
                  duration: Durations.medium2,
                  curve: Curves.easeInOut,
                  width: _searchExpanded ? expandedWidth : collapsedWidth,
                  height: 48,
                  child: AnimatedSwitcher(
                    duration: Durations.short4,
                    child: _searchExpanded
                        ? Row(
                            key: const ValueKey('expanded'),
                            children: [
                              Expanded(
                                child: BlurredTextField(
                                  controller: _searchController,
                                  focusNode: _searchFocusNode,
                                  message: 'Search players…',
                                  onChanged: (v) {
                                    _query = v;
                                    _resetToTop();
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              DarkIconButton(
                                onPressed: _collapseSearch,
                                shadow: false,
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          )
                        : GestureDetector(
                            key: const ValueKey('collapsed'),
                            onTap: _expandSearch,
                            child: BlurredContainer(
                              elevation: 1,
                              radius: 24,
                              height: 48,
                              child: const Center(
                                child: Icon(Icons.search_rounded),
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: buttonGap),
                DarkIconButton(
                  onPressed: _openFilterSheet,
                  icon: Icon(
                    _hasActiveFilters
                        ? Icons.filter_alt_rounded
                        : Icons.filter_alt_outlined,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final matchupsAsync = ref.watch(nearbyMatchupsProvider);
    final incomingAsync = ref.watch(incomingRequestsProvider);
    final outgoingAsync = ref.watch(outgoingRequestsProvider);

    return Scaffold(
      extendBody: true,
      body: SkeletonWidget<List<Matchup>>(
        val: matchupsAsync,
        dummyData: [Matchup.dummy()],
        builder: (List<Matchup> allMatchups) {
          final outgoingByTarget = {
            for (final req in outgoingAsync.value ?? const [])
              req.targetId: req.id,
          };

          final matchups = [
            for (final m in allMatchups)
              if (outgoingByTarget[m.id] == null) m,
          ];

          if (matchups.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: .min,
                  children: [
                    const Icon(Icons.sports_basketball_outlined, size: 48),
                    const SizedBox(height: 12),
                    const Text('No one nearby right now'),
                    const SizedBox(height: 4),
                    Text(
                      'Try widening your search radius in Settings.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    IconButton(
                      icon: Icon(Icons.refresh_rounded),
                      onPressed: () async {
                        nearbyMatchupsProvider.overrideWithValue(
                          AsyncValue.data([]),
                        );
                        ref.invalidate(nearbyMatchupsProvider);
                      },
                    ),
                  ],
                ),
              ),
            );
          }

          final filtered = _applyFilters(matchups);
          final incomingByInitiator = {
            for (final req in incomingAsync.value ?? const [])
              req.initiatorId: req.id,
          };

          return RefreshIndicator(
            onRefresh: () async {
              nearbyMatchupsProvider.overrideWithValue(AsyncValue.data([]));
              ref.invalidate(nearbyMatchupsProvider);
            },
            child: Stack(
              children: [
                if (filtered.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: .min,
                        children: [
                          const Icon(Icons.search_off_rounded, size: 48),
                          const SizedBox(height: 12),
                          const Text('No matches for these filters'),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: _clearFilters,
                            child: const Text('Clear filters'),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  SizedBox.expand(
                    child: PageView.builder(
                      controller: _pageController,
                      physics: const ClampingScrollPhysics(),
                      itemCount: filtered.length,
                      scrollDirection: Axis.vertical,
                      itemBuilder: (context, index) {
                        final matchup = filtered[index];
                        return RepaintBoundary(
                          child: (matchup.id == '')
                              ? Container(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                )
                              : GestureDetector(
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          MatchupViewScreen(matchup: matchup),
                                    ),
                                  ),
                                  child: Hero(
                                    tag: "banner_${matchup.id}",
                                    transitionOnUserGestures: true,
                                    child: Image(
                                      image: ref.read(
                                        imageProviderFamily(matchup.bannerUrl!),
                                      ),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                        );
                      },
                      onPageChanged: (i) => setState(() => _currIndex = i),
                    ),
                  ),
                  _buildMatchupCard(
                    filtered[_currIndex.clamp(0, filtered.length - 1)],
                    context,
                    ref,
                    incomingByInitiator[filtered[_currIndex.clamp(
                          0,
                          filtered.length - 1,
                        )]
                        .id],
                  ),
                ],
                _buildSearchBar(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMatchupCard(
    Matchup matchup,
    BuildContext context,
    WidgetRef ref,
    String? incomingRequestId,
  ) {
    return MatchupCard(
      matchup: matchup,
      hasChallengedYou: incomingRequestId != null,
      onChallenge: () =>
          ProposeMatchScreen.pushProposalWithMatchup(matchup, context),
      onAccept: incomingRequestId == null
          ? null
          : () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  chatId: Chat.pairChatId(
                    matchup.id,
                    ref.read(currentUserIdProvider),
                  ),
                  bannerUrl: matchup.bannerUrl,
                  heroTag: "banner_${matchup.id}",
                ),
              ),
            ),
      myId: ref.read(currentUserIdProvider),
      onChat: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: Chat.pairChatId(
              matchup.id,
              ref.read(currentUserIdProvider),
            ),
            bannerUrl: matchup.bannerUrl,
            heroTag: "banner_${matchup.id}",
          ),
        ),
      ),
    );
  }
}
