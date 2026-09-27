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
      // GET /v1/members returns a bare JSON array (Spatie Data's
      // DataCollection, not a cursor-paginated envelope) — no `data`/
      // `meta` wrapper, unlike most other list endpoints in this app.
      final res = await _dio.get('/v1/members');
      final raw = res.data;
      if (raw is! List) return const [];
      return raw
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
