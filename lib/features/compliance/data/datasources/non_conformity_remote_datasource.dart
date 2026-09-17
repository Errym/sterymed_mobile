import 'package:dio/dio.dart';

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/utils/idempotency_key.dart';
import '../models/non_conformity_data.dart';

class NonConformityRemoteDatasource {
  final Dio _dio;
  NonConformityRemoteDatasource(this._dio);

  Future<List<NonConformityData>> list({String? status}) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.nonConformities,
        queryParameters: {
          if (status != null) 'status': status,
          'per_page': 50,
        },
      );
      final raw = res.data;
      if (raw is! Map || raw['data'] is! List) return const [];
      return (raw['data'] as List)
          .whereType<Map>()
          .map((e) => NonConformityData.fromJson(e.cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<NonConformityData> create({
    required String subjectType,
    required String subjectId,
    required String description,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.nonConformities,
        data: {
          'subject_type': subjectType,
          'subject_id': subjectId,
          'description': description,
        },
        options: Options(
          headers: {'Idempotency-Key': generateIdempotencyKey()},
        ),
      );
      return NonConformityData.fromJson(
        (res.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<void> resolve(String id, {required String resolution}) async {
    try {
      await _dio.post(
        ApiEndpoints.nonConformityResolve(id),
        data: {'resolution': resolution},
        options: Options(
          headers: {'Idempotency-Key': generateIdempotencyKey()},
        ),
      );
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }
}
