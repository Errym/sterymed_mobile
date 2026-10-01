import 'package:dio/dio.dart';

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/errors/error_mapper.dart';
import '../models/device_detail.dart';

class DeviceDetailDatasource {
  final Dio _dio;
  DeviceDetailDatasource(this._dio);

  Future<List<DeviceDetail>> list() async {
    try {
      final res = await _dio.get(
        ApiEndpoints.devices,
        queryParameters: {'limit': 100},
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
      final res = await _dio.get(ApiEndpoints.device(id));
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

  /// [name], [serialNumber] and [status] are sent only when given. [model],
  /// [manufacturer] and [notes] are REQUIRED and always sent: a null means
  /// "clear it". Omitting them would leave the stored value in place, so a user
  /// who emptied the field would see it come back after saving.
  Future<DeviceDetail> update({
    required String id,
    String? name,
    String? serialNumber,
    String? status,
    required String? model,
    required String? manufacturer,
    required String? notes,
  }) async {
    try {
      final res = await _dio.patch(
        ApiEndpoints.device(id),
        data: {
          if (name != null) 'name': name,
          if (serialNumber != null) 'serial_number': serialNumber,
          if (status != null) 'status': status,
          'model': model,
          'manufacturer': manufacturer,
          'notes': notes,
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
      await _dio.delete(ApiEndpoints.device(id));
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }
}
