import 'package:flutter/material.dart';
import 'package:hooper/screens/feed_screen.dart';
import 'package:hooper/screens/inbox_screen.dart';
import 'package:hooper/screens/leaderboard_screen.dart';
import 'package:hooper/screens/profile_screen.dart';
import 'package:hooper/utils.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currPage = 0;

  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    setRadius();
    _pageController = PageController(initialPage: _currPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void setRadius() async {
    await Utils.setRadius();
    setState(() {});
  }

  Widget _buildBottomBar() {
    final rad = (Utils.cornerRadius ?? 20) - 12;
    final icons = [
      Icons.sports_basketball_rounded,
      Icons.chat_rounded,
      Icons.bar_chart_rounded,
      Icons.person_2_rounded,
    ];

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: ClipRSuperellipse(
        borderRadius: BorderRadius.circular(rad),
        child: Container(
          decoration: BoxDecoration(
            color:
                Theme.of(context).navigationBarTheme.backgroundColor ?? Theme.of(context).colorScheme.surfaceContainer,
          ),
          height: 64,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedAlign(
                alignment: FractionalOffset((_currPage) / 3, 0),
                duration: Durations.medium1,
                child: FractionallySizedBox(
                  widthFactor: 0.25,
                  child: Container(
                    decoration: ShapeDecoration(
                      color: const Color.fromARGB(134, 212, 212, 212),
                      shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(rad - 8)),
                    ),
                    margin: EdgeInsets.all(8),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: List.generate(4, (index) {
                  final isCurr = _currPage == index;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onDestination(index),
                      child: SizedBox(
                        width: (MediaQuery.of(context).size.width - 24) / 4,
                        child: Icon(icons[index], size: 26, color: isCurr ? Colors.black : Colors.grey),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: _buildBottomBar(),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() => _currPage = index);
        },
        physics: const ClampingScrollPhysics(),
        children: const [MatchupFeedScreen(), ChatInboxScreen(), LeaderboardScreen(), ProfileScreen()],
      ),
    );
  }

  void onDestination(int index) {
    setState(() {
      _currPage = index;
      _pageController.animateToPage(_currPage, duration: Durations.medium1, curve: Curves.easeInOut);
    });
  }
}
