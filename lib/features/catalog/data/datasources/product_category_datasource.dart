import 'package:dio/dio.dart';

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/utils/idempotency_key.dart';
import '../models/product_category_data.dart';

class ProductCategoryDatasource {
  final Dio _dio;
  ProductCategoryDatasource(this._dio);

  /// GET /v1/product-categories — bare array (confirmed live), same
  /// shape as /devices/{id}/programs.
  Future<List<ProductCategoryData>> list() async {
    try {
      final res = await _dio.get(ApiEndpoints.productCategories);
      final raw = res.data;
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((e) => ProductCategoryData.fromJson(e.cast<String, dynamic>()))
            .toList();
      }
      if (raw is Map && raw['data'] is List) {
        return (raw['data'] as List)
            .whereType<Map>()
            .map((e) => ProductCategoryData.fromJson(e.cast<String, dynamic>()))
            .toList();
      }
      return const [];
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  /// POST /v1/product-categories — replies with the bare created category.
  Future<ProductCategoryData> create(String name) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.productCategories,
        data: {'name': name},
        options: Options(
          headers: {'Idempotency-Key': generateIdempotencyKey()},
        ),
      );
      return ProductCategoryData.fromJson(
        (res.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }
}
