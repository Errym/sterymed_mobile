class UserData {
  final String id;
  final String name;
  final String email;
  final String? role;

  const UserData({
    required this.id,
    required this.name,
    required this.email,
    this.role,
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    String? resolvedRole = json['role']?.toString();

    if (resolvedRole == null && json['roles'] is List) {
      final roles = json['roles'] as List;
      if (roles.isNotEmpty) {
        final first = roles.first;
        if (first is String) {
          resolvedRole = first;
        } else if (first is Map && first['name'] != null) {
          resolvedRole = first['name'].toString();
        }
      }
    }

    return UserData(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: resolvedRole,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        if (role != null) 'role': role,
      };

  UserData copyWith({String? role}) => UserData(
        id: id,
        name: name,
        email: email,
        role: role ?? this.role,
      );
}
