import 'package:dio/dio.dart';

import '../../../../core/errors/error_mapper.dart';
import '../../../../core/utils/idempotency_key.dart';
import '../models/device_program_data.dart';

class DeviceProgramRemoteDatasource {
  final Dio _dio;
  DeviceProgramRemoteDatasource(this._dio);

  /// GET /v1/devices/{device}/programs
  /// Returns a BARE array (not {data: [...]}).
  Future<List<DeviceProgramData>> list(String deviceId) async {
    try {
      final res = await _dio.get(
        '/v1/devices/$deviceId/programs',
        queryParameters: {'per_page': 100},
      );
      final raw = res.data;
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((e) =>
                DeviceProgramData.fromJson(e.cast<String, dynamic>()))
            .toList();
      }
      if (raw is Map && raw['data'] is List) {
        return (raw['data'] as List)
            .whereType<Map>()
            .map((e) =>
                DeviceProgramData.fromJson(e.cast<String, dynamic>()))
            .toList();
      }
      return const [];
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<DeviceProgramData> create({
    required String deviceId,
    required String name,
    required int temperatureCelsius,
    required int plateauMinutes,
    bool isActive = true,
  }) async {
    try {
      final res = await _dio.post(
        '/v1/devices/$deviceId/programs',
        data: {
          'name': name,
          'target_temperature_celsius': temperatureCelsius,
          'plateau_minutes': plateauMinutes,
          'is_active': isActive,
        },
        options: Options(
          headers: {'Idempotency-Key': generateIdempotencyKey()},
        ),
      );
      final raw = res.data;
      if (raw is Map && raw['data'] is Map) {
        return DeviceProgramData.fromJson(
          (raw['data'] as Map).cast<String, dynamic>(),
        );
      }
      return DeviceProgramData.fromJson(
        (raw as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<DeviceProgramData> update({
    required String deviceId,
    required String programId,
    String? name,
    int? temperatureCelsius,
    int? plateauMinutes,
    bool? isActive,
  }) async {
    try {
      final res = await _dio.patch(
        '/v1/devices/$deviceId/programs/$programId',
        data: {
          if (name != null) 'name': name,
          if (temperatureCelsius != null)
            'target_temperature_celsius': temperatureCelsius,
          if (plateauMinutes != null) 'plateau_minutes': plateauMinutes,
          if (isActive != null) 'is_active': isActive,
        },
      );
      final raw = res.data;
      if (raw is Map && raw['data'] is Map) {
        return DeviceProgramData.fromJson(
          (raw['data'] as Map).cast<String, dynamic>(),
        );
      }
      return DeviceProgramData.fromJson(
        (raw as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<void> destroy({
    required String deviceId,
    required String programId,
  }) async {
    try {
      await _dio.delete('/v1/devices/$deviceId/programs/$programId');
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }
}
