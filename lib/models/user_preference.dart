class UserPreference {
  final List<String> blockedUsers;
  final String userId;

  UserPreference({required this.blockedUsers, required this.userId});

  factory UserPreference.fromJson(Map<String, dynamic> data) {
    return UserPreference(
      blockedUsers: ((data['blockedUsers'] as List?) ?? []).cast<String>(),
      userId: data['userId'] as String,
    );
  }
}
