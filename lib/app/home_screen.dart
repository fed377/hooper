import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooper/core/services/providers.dart';
import 'package:hooper/core/utils/utils.dart';
import 'package:hooper/features/chat/presentation/inbox_screen.dart';
import 'package:hooper/features/discovery/presentation/feed_screen.dart';
import 'package:hooper/features/leaderboard/presentation/leaderboard_screen.dart';
import 'package:hooper/features/profile/presentation/profile_screen.dart';

import '../core/widgets/blurred_picker.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

typedef _NavProgress = ({
  double position,
  double? startIndex,
  double? endIndex,
});

class _HomePageState extends ConsumerState<HomePage> {
  double _currPage = 0;

  late PageController _pageController;

  // Driving the bottom nav's indicator purely off scroll position used to
  // call setState() on this whole page every scroll frame, rebuilding the
  // PageView's tab pages along with it. A ValueNotifier lets only the bottom
  // bar's own ValueListenableBuilder rebuild on each frame instead.
  final ValueNotifier<_NavProgress> _navProgress = ValueNotifier((
    position: 0,
    startIndex: null,
    endIndex: null,
  ));

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currPage.toInt());
  }

  @override
  void dispose() {
    _pageController.dispose();
    _navProgress.dispose();
    super.dispose();
  }

  Widget _buildBottomBar(double rad, Duration duration) {
    final icons = [
      Icon(Icons.sports_basketball_rounded, size: 26, color: Colors.black),
      Icon(Icons.chat_rounded, size: 26, color: Colors.black),
      Icon(Icons.bar_chart_rounded, size: 26, color: Colors.black),
      Icon(Icons.person_2_rounded, size: 26, color: Colors.black),
    ];
    void onTap(index) => onDestination(index, duration);
    final radius = rad - 12;
    final height = 64.0;
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: ValueListenableBuilder<_NavProgress>(
        valueListenable: _navProgress,
        builder: (context, nav, _) => BlurredPicker(
          radius: radius,
          height: height,
          progress: nav.position,
          elements: icons,
          onTap: onTap,
          startIndex: nav.startIndex,
          endIndex: nav.endIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(myPreferencesProvider.select((v) => v.value?.glass), (
      previous,
      next,
    ) {
      if (next != null) HooprTheme.instance.glass = next;
    });
    final cornerRadiusAsync = ref.watch(cornerRadiusProvider);

    final duration = Durations.medium3;
    return Scaffold(
      extendBody: true,
      bottomNavigationBar: _buildBottomBar(
        cornerRadiusAsync.when(
          data: (x) => x,
          loading: () => 20,
          error: (_, _) => 20,
        ),
        duration,
      ),
      body: NotificationListener(
        onNotification: (notification) {
          if (notification is ScrollUpdateNotification) {
            final current = _navProgress.value;
            _navProgress.value = (
              position:
                  _pageController.page ??
                  _pageController.initialPage.toDouble(),
              startIndex: notification.dragDetails != null
                  ? null
                  : current.startIndex,
              endIndex: notification.dragDetails != null
                  ? null
                  : current.endIndex,
            );
          }
          return false;
        },
        child: PageView(
          controller: _pageController,
          onPageChanged: (index) => _currPage = index.toDouble(),
          physics: const ClampingScrollPhysics(),
          children: const [
            MatchupFeedScreen(),
            ChatInboxScreen(),
            LeaderboardScreen(),
            ProfileScreen(),
          ],
        ),
      ),
    );
  }

  void onDestination(int index, Duration duration) {
    final start = _currPage;
    _currPage = index.toDouble();
    _navProgress.value = (
      position: _navProgress.value.position,
      startIndex: start,
      endIndex: _currPage,
    );
    _pageController.animateToPage(
      index,
      duration: duration,
      curve: Curves.easeInOut,
    );
  }
}
