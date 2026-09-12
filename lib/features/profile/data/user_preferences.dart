class UserPreference {
  final List<String> blockedUsers;
  final List<String> blockedBy;
  final String userId;
  final bool defaultFriendly;
  final bool defaultPrivate;
  final bool glass;

  UserPreference({
    required this.blockedUsers,
    required this.blockedBy,
    required this.userId,
    this.defaultFriendly = false,
    this.defaultPrivate = false,
    this.glass = false,
  });

  factory UserPreference.fromJson(Map<String, dynamic> data) {
    return UserPreference(
      blockedUsers: ((data['blockedUsers'] as List?) ?? []).cast<String>(),
      blockedBy: ((data['blockedBy'] as List?) ?? []).cast<String>(),
      userId: data['userId'] as String,
      defaultFriendly: data['defaultFriendly'] as bool? ?? false,
      defaultPrivate: data['defaultPrivate'] as bool? ?? false,
      glass: data['glass'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'blockedUsers': blockedUsers,
        'blockedBy': blockedBy,
        'defaultFriendly': defaultFriendly,
        'defaultPrivate': defaultPrivate,
        'glass': glass,
      };
}
