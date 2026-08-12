import 'package:flutter/material.dart';
import 'package:hooper/models/matchup.dart';
import 'package:hooper/utils.dart';
import 'package:progressive_blur/progressive_blur.dart';

class MatchupCard extends StatefulWidget {
  const MatchupCard({
    super.key,
    required this.matchup,
    required this.onChallenge,
    required this.onAccept,
    required this.onChat,
    this.hasChallengedYou = false,
  });
  final Matchup matchup;
  final bool hasChallengedYou;
  final void Function() onChallenge;
  final void Function()? onAccept;
  final void Function() onChat;

  @override
  State<MatchupCard> createState() => _MatchupCardState();
}

class _MatchupCardState extends State<MatchupCard> {
  @override
  Widget build(BuildContext context) {
    const double spacing = 14;
    Matchup match = widget.matchup;
    match.tier;

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
                  child: widget.matchup.bannerUrl == null
                      ? Icon(Icons.question_mark_rounded)
                      : Image.network(widget.matchup.bannerUrl!, fit: BoxFit.cover),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(top: 12, bottom: 12, left: 12, right: 12),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular((Utils.cornerRadius ?? 20) - 2),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: spacing),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                match.displayName,
                                style: TextTheme.of(context).headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const Spacer(),
                              ...List.generate(
                                match.recentForm.length,
                                (index) => Container(
                                  margin: EdgeInsets.all(1),
                                  height: 15,
                                  width: 10,
                                  decoration: BoxDecoration(
                                    color: !match.recentForm[index] ? Colors.red : Colors.green,
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(index == 0 ? 8 : 2),
                                      bottomLeft: Radius.circular(index == 0 ? 8 : 2),
                                      topRight: Radius.circular(index == match.recentForm.length - 1 ? 8 : 2),
                                      bottomRight: Radius.circular(index == match.recentForm.length - 1 ? 8 : 2),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                "${match.elo} ELO",
                                style: TextTheme.of(context).labelLarge?.copyWith(color: Colors.grey),
                              ),
                              const Spacer(),
                              Text("${match.distanceKm} km away"),
                            ],
                          ),
                          const SizedBox(height: spacing),
                          Row(
                            mainAxisSize: MainAxisSize.max,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton.filledTonal(
                                style: ElevatedButton.styleFrom(
                                  shape: CircleBorder(),
                                  minimumSize: Size(0, 50),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  padding: EdgeInsets.all(12),
                                ),
                                icon: Icon(Icons.more_horiz_rounded, size: 24),
                                onPressed: () {},
                              ),
                              const SizedBox(width: spacing),
                              IconButton.filledTonal(
                                style: ElevatedButton.styleFrom(
                                  shape: CircleBorder(),
                                  minimumSize: Size(0, 50),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  padding: EdgeInsets.all(14),
                                ),
                                icon: Icon(Icons.chat_bubble_rounded, size: 20),
                                onPressed: widget.onChat,
                              ),
                              const SizedBox(width: spacing),
                              Expanded(
                                child: FilledButton(
                                  style: ElevatedButton.styleFrom(minimumSize: Size(0, 50)),
                                  onPressed: widget.hasChallengedYou ? widget.onAccept : widget.onChallenge,
                                  child: Text(
                                    widget.hasChallengedYou ? "Accept" : "Play",
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
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
