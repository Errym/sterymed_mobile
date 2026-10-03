import 'package:equatable/equatable.dart';
import '../../../../core/utils/server_time.dart';

/// An invitation that is neither accepted nor revoked: still waiting for the
/// person to join (`pending`) or past its date and needing a resend (`expired`).
class OpenInvitation extends Equatable {
  final String id;
  final String email;
  final String role;
  final bool expired;
  final DateTime? expiresAt;

  const OpenInvitation({
    required this.id,
    required this.email,
    required this.role,
    required this.expired,
    this.expiresAt,
  });

  factory OpenInvitation.fromJson(Map<String, dynamic> json) => OpenInvitation(
    id: json['id']?.toString() ?? '',
    email: json['email']?.toString() ?? '',
    role: json['role']?.toString() ?? '',
    expired: json['status']?.toString() == 'expired',
    expiresAt: parseServerTime(json['expires_at']?.toString() ?? ''),
  );

  @override
  List<Object?> get props => [id, email, role, expired];
}
