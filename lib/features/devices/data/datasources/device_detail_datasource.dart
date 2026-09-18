import 'package:dio/dio.dart';

import '../../../../core/errors/error_mapper.dart';
import '../models/device_detail.dart';

class DeviceDetailDatasource {
  final Dio _dio;
  DeviceDetailDatasource(this._dio);

  Future<List<DeviceDetail>> list() async {
    try {
      final res = await _dio.get(
        '/v1/devices',
        queryParameters: {'per_page': 100},
      );
      final raw = res.data;
      if (raw is! Map || raw['data'] is! List) return const [];
      return (raw['data'] as List)
          .whereType<Map>()
          .map((e) => DeviceDetail.fromJson(e.cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<DeviceDetail> show(String id) async {
    try {
      final res = await _dio.get('/v1/devices/$id');
      final raw = res.data;
      if (raw is Map && raw['data'] is Map) {
        return DeviceDetail.fromJson(
          (raw['data'] as Map).cast<String, dynamic>(),
        );
      }
      return DeviceDetail.fromJson((raw as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<DeviceDetail> update({
    required String id,
    String? name,
    String? model,
    String? serialNumber,
    String? manufacturer,
    String? status,
    String? notes,
  }) async {
    try {
      final res = await _dio.patch(
        '/v1/devices/$id',
        data: {
          if (name != null) 'name': name,
          if (model != null) 'model': model,
          if (serialNumber != null) 'serial_number': serialNumber,
          if (manufacturer != null) 'manufacturer': manufacturer,
          if (status != null) 'status': status,
          if (notes != null) 'notes': notes,
        },
      );
      final raw = res.data;
      if (raw is Map && raw['data'] is Map) {
        return DeviceDetail.fromJson(
          (raw['data'] as Map).cast<String, dynamic>(),
        );
      }
      return DeviceDetail.fromJson((raw as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<void> destroy(String id) async {
    try {
      await _dio.delete('/v1/devices/$id');
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }
}
