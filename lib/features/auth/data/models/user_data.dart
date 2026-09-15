class UserData {
  final String id;
  final String name;
  final String email;
  final String role;

  const UserData({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  factory UserData.fromJson(Map<String, dynamic> json) => UserData(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    email: json['email']?.toString() ?? '',
    role: json['role']?.toString() ?? 'staff',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'role': role,
  };
}
