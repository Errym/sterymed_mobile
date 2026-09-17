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
      if (raw is! Map || raw['data'] is! List) return const [];
      return (raw['data'] as List)
          .whereType<Map>()
          .map((e) => DeviceData.fromJson(e.cast<String, dynamic>()))
          .toList();
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
      return DeviceData.fromJson((res.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }
}
