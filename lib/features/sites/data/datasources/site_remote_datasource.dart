import 'package:dio/dio.dart';

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/utils/idempotency_key.dart';
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

  Future<SiteData> create({
    required String name,
    String? addressLine1,
    String? city,
    bool isPrimary = false,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.sites,
        data: {
          'name': name,
          if (addressLine1 != null) 'address_line1': addressLine1,
          if (city != null) 'city': city,
          'is_primary': isPrimary,
        },
        options: Options(
          headers: {'Idempotency-Key': generateIdempotencyKey()},
        ),
      );
      return _parseOne(res.data);
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  List<SiteData> _parseList(dynamic raw) {
    // Shape A: { data: [...] }
    if (raw is Map && raw['data'] is List) {
      return (raw['data'] as List)
          .whereType<Map>()
          .map((e) => SiteData.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    // Shape B: { items: [...] } or { sites: [...] }
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
    // Shape C: bare array
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => SiteData.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    return const [];
  }

  SiteData _parseOne(dynamic raw) {
    if (raw is Map) {
      // Shape: { data: {...} }
      if (raw['data'] is Map) {
        return SiteData.fromJson(
          (raw['data'] as Map).cast<String, dynamic>(),
        );
      }
      // Shape: bare object
      return SiteData.fromJson(raw.cast<String, dynamic>());
    }
    throw const FormatException('Réponse de site invalide.');
  }
}
