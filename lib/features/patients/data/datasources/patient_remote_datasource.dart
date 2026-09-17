import 'package:dio/dio.dart';

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/utils/idempotency_key.dart';
import '../models/patient_create_request.dart';
import '../models/patient_data.dart';

class PatientRemoteDatasource {
  final Dio _dio;
  PatientRemoteDatasource(this._dio);

  Future<List<PatientData>> search(String query) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.patients,
        queryParameters: {
          if (query.trim().isNotEmpty) 'search': query.trim(),
          'per_page': 30,
        },
      );
      final raw = res.data;
      if (raw is! Map || raw['data'] is! List) return const [];
      return (raw['data'] as List)
          .whereType<Map>()
          .map((e) => PatientData.fromJson(e.cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<PatientData> create(PatientCreateRequest req) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.patients,
        data: req.toJson(),
        options: Options(
          headers: {'Idempotency-Key': generateIdempotencyKey()},
        ),
      );
      return PatientData.fromJson(
        (res.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<PatientData> show(String id) async {
    try {
      final res = await _dio.get(ApiEndpoints.patient(id));
      return PatientData.fromJson(
        (res.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<void> destroy(String id) async {
    try {
      await _dio.delete(ApiEndpoints.patient(id));
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }
}
