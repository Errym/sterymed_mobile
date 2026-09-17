import 'package:dio/dio.dart';

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/utils/idempotency_key.dart';
import '../models/product_data.dart';

class ProductRemoteDatasource {
  final Dio _dio;
  ProductRemoteDatasource(this._dio);

  Future<List<ProductData>> list({String? search}) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.products,
        queryParameters: {
          if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
          'per_page': 100,
        },
      );
      final raw = res.data;
      if (raw is! Map || raw['data'] is! List) return const [];
      return (raw['data'] as List)
          .whereType<Map>()
          .map((e) => ProductData.fromJson(e.cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<ProductData> create(ProductCreateRequest req) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.products,
        data: req.toJson(),
        options: Options(
          headers: {'Idempotency-Key': generateIdempotencyKey()},
        ),
      );
      return ProductData.fromJson((res.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<ProductData> update(String id, ProductCreateRequest req) async {
    try {
      final res = await _dio.patch(
        ApiEndpoints.product(id),
        data: req.toJson(),
      );
      return ProductData.fromJson((res.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<void> destroy(String id) async {
    try {
      await _dio.delete(ApiEndpoints.product(id));
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }
}
