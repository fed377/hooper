import 'package:flutter/material.dart';
import 'package:hooper/utils.dart';
import 'package:progressive_blur/progressive_blur.dart';

class Discover extends StatelessWidget {
  const Discover({super.key});

  @override
  Widget build(BuildContext context) {
    return MatchCard();
  }
}

class MatchCard extends StatelessWidget {
  const MatchCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 46, left: 12, right: 12, bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular((Utils.cornerRadius ?? 20)),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular((Utils.cornerRadius ?? 20)),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: ProgressiveBlurWidget(
                  sigma: 24,
                  linearGradientBlur: LinearGradientBlur(
                    values: [1, 0.8, 0],
                    stops: [0, 0.4, 0.55],
                    start: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                  child: Image.network(
                    "https://upload.wikimedia.org/wikipedia/commons/7/7a/LeBron_James_%2851959977144%29_%28cropped2%29.jpg",
                    fit: BoxFit.cover,
                  ),
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
                        borderRadius: BorderRadius.circular((Utils.cornerRadius ?? 20) - 12),
                      ),
                      child: Row(
                        children: [TextButton(child: Text("Play"), onPressed: () {})],
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
