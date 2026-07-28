enum Tier { rookie, rising, baller, pro, elite }

Tier tierForElo(int elo) {
  if (elo >= 1900) return Tier.elite;
  if (elo >= 1600) return Tier.pro;
  if (elo >= 1300) return Tier.baller;
  if (elo >= 1000) return Tier.rising;
  return Tier.rookie;
}

String tierLabel(Tier tier) {
  switch (tier) {
    case Tier.rookie:
      return 'Rookie';
    case Tier.rising:
      return 'Rising';
    case Tier.baller:
      return 'Baller';
    case Tier.pro:
      return 'Pro';
    case Tier.elite:
      return 'Elite';
  }
}

class Matchup {
  final String id;
  final String name;
  final String? photoUrl;
  final int elo;
  final double distanceKm;
  final List<bool> recentForm;
  final bool isLocked;
  final DateTime lastActive;

  Matchup({
    required this.id,
    required this.name,
    required this.elo,
    required this.distanceKm,
    required this.recentForm,
    this.photoUrl,
    this.isLocked = false,
    DateTime? lastActive,
  }) : lastActive = lastActive ?? DateTime.now();

  Tier get tier => tierForElo(elo);

  factory Matchup.fromJson(Map<String, dynamic> data) {
    return Matchup(
      id: data['id'] as String,
      name: data['name'] as String,
      photoUrl: data['photoUrl'] as String?,
      elo: data['elo'] as int,
      distanceKm: (data['distanceKm'] as num).toDouble(),
      recentForm: (data['recentForm'] as List).cast<bool>(),
      isLocked: data['isLocked'] as bool? ?? false,
      lastActive: data['lastActive'] != null
          ? DateTime.parse(data['lastActive'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'photoUrl': photoUrl,
      'elo': elo,
      'recentForm': recentForm,
      'isLocked': isLocked,
      'lastActive': lastActive.toIso8601String(),
    };
  }
}