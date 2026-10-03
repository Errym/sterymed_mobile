import 'package:dio/dio.dart';

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/utils/idempotency_key.dart';
import '../models/open_invitation.dart';
import '../models/team_member_data.dart';

class TeamRemoteDatasource {
  final Dio _dio;
  TeamRemoteDatasource(this._dio);

  Future<List<TeamMemberData>> list() async {
    try {
      // GET /v1/members returns a bare JSON array (Spatie Data's
      // DataCollection, not a cursor-paginated envelope) — no `data`/
      // `meta` wrapper, unlike most other list endpoints in this app.
      final res = await _dio.get(ApiEndpoints.members);
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

  Future<void> invite({required String email, required String role}) async {
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

  /// Invitations still waiting for an answer (pending or expired). A bare JSON
  /// array, like `/members`.
  Future<List<OpenInvitation>> listInvitations() async {
    try {
      final res = await _dio.get(ApiEndpoints.invitations);
      final raw = res.data;
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => OpenInvitation.fromJson(e.cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<void> resendInvitation(String id) async {
    try {
      await _dio.post(ApiEndpoints.invitationResend(id));
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<void> revokeInvitation(String id) async {
    try {
      await _dio.delete(ApiEndpoints.invitation(id));
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
