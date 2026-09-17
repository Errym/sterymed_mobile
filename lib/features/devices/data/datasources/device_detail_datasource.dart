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
}
