class Court {
  final String id;
  final String name;
  final bool verified;

  Court({required this.id, required this.name, this.verified = false});

  factory Court.fromJson(Map<String, dynamic> json) {
    return Court(id: json['id'] as String, name: json['name'] as String, verified: json['verified'] as bool? ?? false);
  }
}
