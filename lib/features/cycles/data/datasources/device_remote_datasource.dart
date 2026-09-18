import 'package:dio/dio.dart';

import '../../../../core/errors/error_mapper.dart';
import '../../../../core/utils/idempotency_key.dart';
import '../models/device_data.dart';

class DeviceRemoteDatasource {
  final Dio _dio;
  DeviceRemoteDatasource(this._dio);

  Future<List<DeviceData>> list() async {
    try {
      final res = await _dio.get(
        '/v1/devices',
        queryParameters: {'per_page': 100},
      );

      final raw = res.data;

      // Tolerate: {data: [...]}
      if (raw is Map && raw['data'] is List) {
        return (raw['data'] as List)
            .whereType<Map>()
            .map((e) => DeviceData.fromJson(e.cast<String, dynamic>()))
            .toList();
      }

      // Tolerate: bare array
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((e) => DeviceData.fromJson(e.cast<String, dynamic>()))
            .toList();
      }

      // Tolerate: {items: [...]} or {devices: [...]}
      if (raw is Map) {
        for (final key in ['items', 'devices', 'results']) {
          final v = raw[key];
          if (v is List) {
            return v
                .whereType<Map>()
                .map((e) => DeviceData.fromJson(e.cast<String, dynamic>()))
                .toList();
          }
        }
      }

      // No idea what this is — but tell the caller instead of pretending
      // we got an empty list. They can see the actual response in the UI.
      throw FormatException(
        'Réponse inattendue du serveur (devices): ${raw.runtimeType}',
      );
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<DeviceData> create({
    required String siteId,
    required String name,
    required String serialNumber,
    required String kind,
    String? manufacturer,
    String? model,
    String? notes,
  }) async {
    try {
      final res = await _dio.post(
        '/v1/devices',
        data: {
          'site_id': siteId,
          'name': name,
          'serial_number': serialNumber,
          'kind': kind,
          'status': 'active',
          if (manufacturer != null) 'manufacturer': manufacturer,
          if (model != null) 'model': model,
          if (notes != null) 'notes': notes,
        },
        options: Options(
          headers: {'Idempotency-Key': generateIdempotencyKey()},
        ),
      );
      final raw = res.data;
      if (raw is Map && raw['data'] is Map) {
        return DeviceData.fromJson(
          (raw['data'] as Map).cast<String, dynamic>(),
        );
      }
      return DeviceData.fromJson((raw as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }
}
