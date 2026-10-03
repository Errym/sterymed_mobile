import 'package:equatable/equatable.dart';
import '../../../../core/utils/server_time.dart';

class TeamMemberData extends Equatable {
  final String id;
  final String userId;
  final String name;
  final String email;
  final String? role;
  final String status;
  final DateTime? joinedAt;
  final DateTime? disabledAt;

  const TeamMemberData({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    this.role,
    required this.status,
    this.joinedAt,
    this.disabledAt,
  });

  bool get active => status == 'active';

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
    role: json['role']?.toString(),
    status: json['status']?.toString() ?? 'active',
    joinedAt: parseServerTime(json['joined_at']?.toString() ?? ''),
    disabledAt: parseServerTime(json['disabled_at']?.toString() ?? ''),
  );

  @override
  List<Object?> get props => [id, userId, role, status];
}
