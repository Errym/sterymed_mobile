import 'package:dio/dio.dart';

import '../../../../core/errors/error_mapper.dart';
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
}
