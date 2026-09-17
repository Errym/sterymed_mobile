import 'package:dio/dio.dart';

import '../../../../core/errors/error_mapper.dart';
import '../../../../core/utils/idempotency_key.dart';
import '../models/export_request_data.dart';

class ExportRemoteDatasource {
  final Dio _dio;
  ExportRemoteDatasource(this._dio);

  Future<List<ExportRequestData>> list() async {
    try {
      final res = await _dio.get(
        '/v1/data-export-requests',
        queryParameters: {'per_page': 50},
      );
      final raw = res.data;
      if (raw is! Map || raw['data'] is! List) return const [];
      return (raw['data'] as List)
          .whereType<Map>()
          .map((e) => ExportRequestData.fromJson(e.cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<ExportRequestData> request() async {
    try {
      final res = await _dio.post(
        '/v1/data-export-requests',
        options: Options(
          headers: {'Idempotency-Key': generateIdempotencyKey()},
        ),
      );
      return ExportRequestData.fromJson(
        (res.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<String> downloadUrl(String id) async {
    try {
      final res = await _dio.post('/v1/data-export-requests/$id/download');
      final data = (res.data as Map).cast<String, dynamic>();
      return data['download_url']?.toString() ?? '';
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }
}
