import 'package:flutter/material.dart';
import 'package:hooper/models/matchup.dart';
import 'package:hooper/utils.dart';
import 'package:progressive_blur/progressive_blur.dart';

class Discover extends StatelessWidget {
  const Discover({super.key});

  @override
  Widget build(BuildContext context) {
    return MatchCard(
      matchup: Matchup(
        id: "asdf",
        name: "Lebron James",
        elo: 20000,
        distanceKm: 10,
        recentForm: [true, true, false, false],
        photoUrl:
            "https://upload.wikimedia.org/wikipedia/commons/7/7a/LeBron_James_%2851959977144%29_%28cropped2%29.jpg",
        lastActive: DateTime.now().add(Duration(days: 1)),
      ),
    );
  }
}

class MatchCard extends StatefulWidget {
  const MatchCard({super.key, required this.matchup});
  final Matchup matchup;

  @override
  State<MatchCard> createState() => _MatchCardState();
}

class _MatchCardState extends State<MatchCard> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 46, left: 12, right: 12, bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular((Utils.cornerRadius ?? 20) + 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular((Utils.cornerRadius ?? 20) + 10),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: ProgressiveBlurWidget(
                  sigma: 24,
                  linearGradientBlur: LinearGradientBlur(
                    values: [1, 0.8, 0],
                    stops: [0, 0.3, 0.55],
                    start: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                  child: widget.matchup.photoUrl == null
                      ? Container()
                      : Image.network(widget.matchup.photoUrl!, fit: BoxFit.cover),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(top: 12, bottom: 12, left: 12, right: 12),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    heightFactor: 0.3,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular((Utils.cornerRadius ?? 20) - 2),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 0),
                        child: Row(
                          mainAxisSize: MainAxisSize.max,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            FilledButton.tonal(
                              style: ElevatedButton.styleFrom(shape: CircleBorder(), minimumSize: Size(0, 50)),
                              child: Icon(
                                Icons.more_horiz_rounded,
                                size: (Theme.of(context).iconTheme.size ?? 24) * 0.8,
                              ),
                              onPressed: () {},
                            ),
                            FilledButton.tonal(
                              style: ElevatedButton.styleFrom(shape: CircleBorder(), minimumSize: Size(0, 50)),
                              child: Icon(
                                Icons.chat_bubble_rounded,
                                size: (Theme.of(context).iconTheme.size ?? 24) * 0.8,
                              ),
                              onPressed: () {},
                            ),
                            Expanded(
                              child: FilledButton(
                                style: ElevatedButton.styleFrom(minimumSize: Size(0, 50)),
                                child: Text("Play", style: TextStyle(fontSize: 16)),
                                onPressed: () {},
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
