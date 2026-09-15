import 'package:dio/dio.dart';

import '../../../../core/config/api_endpoints.dart';
import '../models/login_response.dart';
import '../models/user_data.dart';
import '../models/tenant_data.dart';

class AuthRemoteDatasource {
  final Dio _dio;

  AuthRemoteDatasource(this._dio);

  Future<LoginResponse> login({
    required String tenantSlug,
    required String email,
    required String password,
  }) async {
    final response = await _dio.post(
      ApiEndpoints.login,
      data: {'tenant_slug': tenantSlug, 'email': email, 'password': password},
    );
    return LoginResponse.fromJson(
      (response.data as Map).cast<String, dynamic>(),
    );
  }

  Future<void> logout() async {
    await _dio.delete(ApiEndpoints.logout);
  }

  Future<void> logoutEverywhere() async {
    await _dio.delete(ApiEndpoints.logoutEverywhere);
  }

  Future<({UserData user, TenantData tenant})> me() async {
    final response = await _dio.get(ApiEndpoints.me);
    final data = (response.data as Map).cast<String, dynamic>();
    return (
      user: UserData.fromJson((data['user'] as Map).cast<String, dynamic>()),
      tenant: TenantData.fromJson(
        (data['tenant'] as Map).cast<String, dynamic>(),
      ),
    );
  }
  Future<LoginResponse> register({
    required String tenantName,
    required String tenantSlug,
    required String ownerName,
    required String ownerEmail,
    required String password,
  }) async {
    final response = await _dio.post(
      ApiEndpoints.register,
      data: {
        'tenant_name': tenantName,
        'tenant_slug': tenantSlug,
        'owner_name': ownerName,
        'owner_email': ownerEmail,
        'password': password,
      },
    );
    return LoginResponse.fromJson(
      (response.data as Map).cast<String, dynamic>(),
    );
  }
}
