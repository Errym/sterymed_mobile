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
          'per_page': 100,
        },
      );
      return _parseList(res.data);
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
      return _parseOne(res.data);
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<PatientData> show(String id) async {
    try {
      final res = await _dio.get(ApiEndpoints.patient(id));
      return _parseOne(res.data);
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

  // ── tolerant parsers ─────────────────────────────────────────────────
  List<PatientData> _parseList(dynamic raw) {
    if (raw is Map && raw['data'] is List) {
      return (raw['data'] as List)
          .whereType<Map>()
          .map((e) => PatientData.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => PatientData.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    if (raw is Map) {
      for (final key in ['items', 'patients', 'results']) {
        final v = raw[key];
        if (v is List) {
          return v
              .whereType<Map>()
              .map((e) => PatientData.fromJson(e.cast<String, dynamic>()))
              .toList();
        }
      }
    }
    return const [];
  }

  PatientData _parseOne(dynamic raw) {
    if (raw is Map && raw['data'] is Map) {
      return PatientData.fromJson(
        (raw['data'] as Map).cast<String, dynamic>(),
      );
    }
    if (raw is Map) {
      return PatientData.fromJson(raw.cast<String, dynamic>());
    }
    throw const FormatException('Réponse patient invalide');
  }
}
