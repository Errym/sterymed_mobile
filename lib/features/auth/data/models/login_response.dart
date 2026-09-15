import 'user_data.dart';
import 'tenant_data.dart';

class LoginResponse {
  final String token;
  final String tokenType;
  final UserData user;
  final TenantData tenant;

  const LoginResponse({
    required this.token,
    required this.tokenType,
    required this.user,
    required this.tenant,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) => LoginResponse(
    token: json['token']?.toString() ?? '',
    tokenType: json['token_type']?.toString() ?? 'Bearer',
    user: UserData.fromJson((json['user'] as Map).cast<String, dynamic>()),
    tenant: TenantData.fromJson(
      (json['tenant'] as Map).cast<String, dynamic>(),
    ),
  );
}
