import 'package:dio/dio.dart';

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/errors/error_mapper.dart';
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

  Future<void> logout({String? token}) async {
    await _dio.delete(ApiEndpoints.logout, options: _revocationOptions(token));
  }

  /// Asks the server to e-mail a reset link. Password reset is per person, not
  /// per practice, so only the address is sent. The server answers 202 whether
  /// or not an account exists (it never reveals who has one).
  Future<void> forgotPassword({required String email}) async {
    try {
      await _dio.post(ApiEndpoints.forgotPassword, data: {'email': email});
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<void> logoutEverywhere({String? token}) async {
    await _dio.delete(
      ApiEndpoints.logoutEverywhere,
      options: _revocationOptions(token),
    );
  }

  Options _revocationOptions(String? token) => Options(
    headers: {if (token != null) 'Authorization': 'Bearer $token'},
    extra: {'detachedRevocation': true},
  );

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
