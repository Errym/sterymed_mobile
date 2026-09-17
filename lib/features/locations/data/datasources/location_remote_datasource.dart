import 'package:dio/dio.dart';

import '../../../../core/errors/error_mapper.dart';
import '../../../../core/utils/idempotency_key.dart';
import '../models/location_data.dart';

class LocationRemoteDatasource {
  final Dio _dio;
  LocationRemoteDatasource(this._dio);

  Future<List<LocationData>> listForSite(String siteId) async {
    try {
      final res = await _dio.get(
        '/v1/sites/$siteId/locations',
        queryParameters: {'per_page': 100},
      );
      final raw = res.data;
      if (raw is! Map || raw['data'] is! List) return const [];
      return (raw['data'] as List)
          .whereType<Map>()
          .map((e) => LocationData.fromJson(e.cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<LocationData> create({
    required String siteId,
    required String name,
    required String kind,
  }) async {
    try {
      final res = await _dio.post(
        '/v1/sites/$siteId/locations',
        data: {'name': name, 'kind': kind},
        options: Options(
          headers: {'Idempotency-Key': generateIdempotencyKey()},
        ),
      );
      return LocationData.fromJson((res.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }
}
