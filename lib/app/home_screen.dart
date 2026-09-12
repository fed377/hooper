import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooper/core/services/providers.dart';
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

class _HomePageState extends ConsumerState<HomePage> {
  double _currPage = 0;

  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currPage.toInt());
  }

  @override
  void dispose() {
    _pageController.dispose();
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
      child: BlurredPicker(
        radius: radius,
        height: height,
        progress: _pagePosition,
        elements: icons,
        onTap: onTap,
        startIndex: startIndex,
        endIndex: endIndex,
      ),
    );
  }

  double _pagePosition = 0.0;

  @override
  Widget build(BuildContext context) {
    final cornerRadiusAsync = ref.watch(cornerRadiusProvider);

    final duration = Durations.medium3;
    return Scaffold(
      extendBody: true,
      bottomNavigationBar: _buildBottomBar(
        cornerRadiusAsync.when(data: (x) => x, loading: () => 20, error: (_, _) => 20),
        duration,
      ),
      body: NotificationListener(
        onNotification: (notification) {
          if (notification is ScrollUpdateNotification) {
            setState(() {
              if (notification.dragDetails != null) {
                startIndex = null;
                endIndex = null;
              }
              _pagePosition = _pageController.page ?? _pageController.initialPage.toDouble();
            });
          }
          return false;
        },
        child: PageView(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() => _currPage = index.toDouble());
          },
          physics: const ClampingScrollPhysics(),
          children: const [MatchupFeedScreen(), ChatInboxScreen(), LeaderboardScreen(), ProfileScreen()],
        ),
      ),
    );
  }

  double? startIndex;
  double? endIndex;

  void onDestination(int index, Duration duration) {
    setState(() {
      startIndex = _currPage;
      _currPage = index.toDouble();
      endIndex = _currPage;
      _pageController.animateToPage(index, duration: duration, curve: Curves.easeInOut);
    });
  }
}
