import 'package:dio/dio.dart';

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/utils/idempotency_key.dart';
import '../models/team_member_data.dart';

class TeamRemoteDatasource {
  final Dio _dio;
  TeamRemoteDatasource(this._dio);

  Future<List<TeamMemberData>> list() async {
    try {
      final res = await _dio.get(
        '/v1/members',
        queryParameters: {'per_page': 100},
      );
      final raw = res.data;
      if (raw is! Map || raw['data'] is! List) return const [];
      return (raw['data'] as List)
          .whereType<Map>()
          .map((e) => TeamMemberData.fromJson(e.cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return const [];
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<void> invite({
    required String email,
    required String role,
  }) async {
    try {
      await _dio.post(
        ApiEndpoints.invitations,
        data: {'email': email, 'role': role},
        options: Options(
          headers: {'Idempotency-Key': generateIdempotencyKey()},
        ),
      );
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<void> disable(String tenantUserId) async {
    try {
      await _dio.delete(ApiEndpoints.member(tenantUserId));
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }
}
