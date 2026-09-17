import 'package:equatable/equatable.dart';

class TeamMemberData extends Equatable {
  final String id;
  final String userId;
  final String name;
  final String email;
  final String role;
  final bool active;
  final String? locationLabel;
  final DateTime? createdAt;
  final DateTime? lastSessionAt;

  const TeamMemberData({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    required this.active,
    this.locationLabel,
    this.createdAt,
    this.lastSessionAt,
  });

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  factory TeamMemberData.fromJson(Map<String, dynamic> json) => TeamMemberData(
        id: json['id']?.toString() ?? '',
        userId: json['user_id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        role: json['role']?.toString() ?? 'viewer',
        active: json['active'] as bool? ?? true,
        locationLabel: json['location_label']?.toString(),
        createdAt:
            DateTime.tryParse(json['created_at']?.toString() ?? ''),
        lastSessionAt:
            DateTime.tryParse(json['last_session_at']?.toString() ?? ''),
      );

  @override
  List<Object?> get props => [id, userId, role, active];
}
