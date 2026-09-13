import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooper/core/utils/utils.dart' as utils;
import 'package:hooper/features/discovery/data/matchup.dart';
import 'package:hooper/features/matches/data/match_doc.dart';
import 'package:hooper/features/matches/presentation/match_view_screen.dart';

class MatchListTile extends ConsumerWidget {
  const MatchListTile({
    super.key,
    required this.match,
    required this.radius,
    required this.matchup,
  });
  final MatchDoc match;
  final Matchup matchup;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MatchViewScreen(matchId: match.id),
          ),
        ),
        title: Text(matchup.displayName),
        subtitle: Text(utils.formatDate(match.scheduledTime)),
        leading: CircleAvatar(
          backgroundImage: matchup.photoUrl != null
              ? ResizeImage(
                  CachedNetworkImageProvider(matchup.photoUrl!),
                  width: 120,
                )
              : null,
          child: matchup.photoUrl == null ? Text(matchup.displayName[0]) : null,
        ),
      ),
    );
  }
}
