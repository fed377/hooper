import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooper/models/match_doc.dart';
import 'package:hooper/models/matchup.dart';
import 'package:hooper/screens/match_view_screen.dart';
import 'package:hooper/utils.dart';

class MatchListTile extends ConsumerWidget {
  const MatchListTile({super.key, required this.match, required this.radius, required this.matchup});
  final MatchDoc match;
  final Matchup matchup;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: ShapeDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(radius)),
      ),
      child: GestureDetector(
        onTap: () =>
            Navigator.of(context).push(MaterialPageRoute(builder: (context) => MatchViewScreen(matchId: match.id))),
        child: buildListTile(matchup),
      ),
    );
  }

  Widget buildListTile(Matchup matchup) {
    return ListTile(
      title: Text(matchup.displayName),
      subtitle: Text(Utils.formatDate(match.scheduledTime)),
      leading: CircleAvatar(
        backgroundImage: matchup.photoUrl != null ? NetworkImage(matchup.photoUrl!) : null,
        child: matchup.photoUrl == null ? Text(matchup.displayName[0]) : null,
      ),
    );
  }
}
