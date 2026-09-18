import 'package:dio/dio.dart';

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/errors/error_mapper.dart';
import '../models/site_data.dart';

class SiteRemoteDatasource {
  final Dio _dio;
  SiteRemoteDatasource(this._dio);

  Future<List<SiteData>> list() async {
    try {
      final res = await _dio.get(
        ApiEndpoints.sites,
        queryParameters: {'per_page': 100},
      );
      return _parseList(res.data);
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  List<SiteData> _parseList(dynamic raw) {
    if (raw is Map && raw['data'] is List) {
      return (raw['data'] as List)
          .whereType<Map>()
          .map((e) => SiteData.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    if (raw is Map) {
      for (final key in ['items', 'sites', 'results']) {
        final v = raw[key];
        if (v is List) {
          return v
              .whereType<Map>()
              .map((e) => SiteData.fromJson(e.cast<String, dynamic>()))
              .toList();
        }
      }
    }
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => SiteData.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    return const [];
  }
}
