import 'package:dio/dio.dart';

import '../../../../core/errors/error_mapper.dart';
import '../models/batch_data.dart';

class BatchRemoteDatasource {
  final Dio _dio;
  BatchRemoteDatasource(this._dio);

  Future<List<BatchData>> list() async {
    try {
      final res = await _dio.get(
        '/v1/batches',
        queryParameters: {'per_page': 100},
      );
      final raw = res.data;
      if (raw is! Map || raw['data'] is! List) return const [];
      return (raw['data'] as List)
          .whereType<Map>()
          .map((e) => BatchData.fromJson(e.cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }
}
