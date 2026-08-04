import 'package:flutter/material.dart';
import 'package:hooper/discover_page.dart';
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

  final icons = [Icons.search_rounded, Icons.chat_rounded, Icons.bar_chart_rounded, Icons.person_2_rounded];

  Widget buildBottomBar(double rad) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(rad),
        child: Container(
          decoration: BoxDecoration(
            color:
                Theme.of(context).navigationBarTheme.backgroundColor ?? Theme.of(context).colorScheme.surfaceContainer,
          ),
          height: 64,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: List.generate(4, (index) {
              final isCurr = _currPage == index;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onDestination(index),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedOpacity(
                        opacity: isCurr ? 1 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                          decoration: BoxDecoration(
                            boxShadow: [BoxShadow(blurRadius: 10, spreadRadius: 2, color: Colors.black.withAlpha(50))],
                            color:
                                Theme.of(context).navigationBarTheme.backgroundColor ??
                                Theme.of(context).colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(rad - 8),
                          ),
                          margin: EdgeInsets.all(8),
                        ),
                      ),
                      Icon(icons[index], size: 26, color: Colors.black),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double rad = Utils.cornerRadius ?? 20;
    rad -= 12;

    return Scaffold(
      bottomNavigationBar: buildBottomBar(rad),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currPage = index;
          });
        },
        physics: const ClampingScrollPhysics(),
        children: const [
          Discover(),
          Center(child: Text('Search Screen', style: TextStyle(fontSize: 24))),
          Center(child: Text('Profile Screen', style: TextStyle(fontSize: 24))),
          Center(child: Text('Profile Screen', style: TextStyle(fontSize: 24))),
        ],
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
