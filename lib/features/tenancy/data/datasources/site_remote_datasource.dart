import 'package:dio/dio.dart';

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/errors/error_mapper.dart';
import '../models/site_data.dart';

class SiteRemoteDatasource {
  final Dio _dio;
  SiteRemoteDatasource(this._dio);

  Future<List<SiteData>> list() async {
    try {
      final res = await _dio.get(ApiEndpoints.sites);
      final raw = res.data;
      if (raw is! Map || raw['data'] is! List) return const [];
      return (raw['data'] as List)
          .whereType<Map>()
          .map((e) => SiteData.fromJson(e.cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }
}
