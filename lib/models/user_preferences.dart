class UserPreference {
  final List<String> blockedUsers;
  final List<String> blockedBy;
  final String userId;

  UserPreference({required this.blockedUsers, required this.userId, required this.blockedBy});

  factory UserPreference.fromJson(Map<String, dynamic> data) {
    return UserPreference(
      blockedUsers: ((data['blockedUsers'] as List?) ?? []).cast<String>(),
      userId: data['userId'] as String,
      blockedBy: ((data['blockedBy'] as List?) ?? []).cast<String>(),
    );
  }
}
