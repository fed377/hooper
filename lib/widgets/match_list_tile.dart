import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooper/models/match_doc.dart';
import 'package:hooper/models/matchup.dart';
import 'package:hooper/screens/match_view_screen.dart';
import 'package:hooper/core/utils/utils.dart' as utils;

class MatchListTile extends ConsumerWidget {
  const MatchListTile({super.key, required this.match, required this.radius, required this.matchup});
  final MatchDoc match;
  final Matchup matchup;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var matchup2 = matchup;
    return Container(
      decoration: ShapeDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: RoundedSuperellipseBorder(borderRadius: .circular(radius)),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          onTap: () =>
              Navigator.of(context).push(MaterialPageRoute(builder: (context) => MatchViewScreen(matchId: match.id))),
          title: Text(matchup2.displayName),
          subtitle: Text(utils.formatDate(match.scheduledTime)),
          leading: CircleAvatar(
            backgroundImage: matchup2.photoUrl != null ? CachedNetworkImageProvider(matchup2.photoUrl!) : null,
            child: matchup2.photoUrl == null ? Text(matchup2.displayName[0]) : null,
          ),
        ),
      ),
    );
  }
}
