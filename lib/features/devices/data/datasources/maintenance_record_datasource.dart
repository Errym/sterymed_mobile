import 'package:dio/dio.dart';

import '../../../../core/errors/error_mapper.dart';
import '../../../../core/utils/idempotency_key.dart';
import '../models/maintenance_record_data.dart';

class MaintenanceRecordDatasource {
  final Dio _dio;
  MaintenanceRecordDatasource(this._dio);

  /// GET /v1/devices/{device}/maintenance-records
  /// Controller returns a bare array (Data collection ->all()), same
  /// shape as GET /devices/{device}/programs.
  Future<List<MaintenanceRecordData>> list(String deviceId) async {
    try {
      final res = await _dio.get('/v1/devices/$deviceId/maintenance-records');
      final raw = res.data;
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((e) =>
                MaintenanceRecordData.fromJson(e.cast<String, dynamic>()))
            .toList();
      }
      if (raw is Map && raw['data'] is List) {
        return (raw['data'] as List)
            .whereType<Map>()
            .map((e) =>
                MaintenanceRecordData.fromJson(e.cast<String, dynamic>()))
            .toList();
      }
      return const [];
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  /// POST /v1/devices/{device}/maintenance-records
  /// kind: required, one of preventive|corrective|calibration
  /// technician: nullable
  /// performed_at: required date
  /// next_due_at: nullable, must be after performed_at
  /// description: nullable
  Future<MaintenanceRecordData> create({
    required String deviceId,
    required String kind,
    String? technician,
    required DateTime performedAt,
    DateTime? nextDueAt,
    String? description,
  }) async {
    try {
      final res = await _dio.post(
        '/v1/devices/$deviceId/maintenance-records',
        data: {
          'kind': kind,
          if (technician != null && technician.isNotEmpty)
            'technician': technician,
          'performed_at': performedAt.toIso8601String(),
          if (nextDueAt != null) 'next_due_at': nextDueAt.toIso8601String(),
          if (description != null && description.isNotEmpty)
            'description': description,
        },
        options: Options(
          headers: {'Idempotency-Key': generateIdempotencyKey()},
        ),
      );
      final raw = res.data;
      if (raw is Map && raw['data'] is Map) {
        return MaintenanceRecordData.fromJson(
          (raw['data'] as Map).cast<String, dynamic>(),
        );
      }
      return MaintenanceRecordData.fromJson(
        (raw as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }
}
