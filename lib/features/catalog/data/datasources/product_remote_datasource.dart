import 'package:dio/dio.dart';

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/network/cursor_page.dart';
import '../../../../core/utils/idempotency_key.dart';
import '../models/product_data.dart';

class ProductRemoteDatasource {
  final Dio _dio;
  ProductRemoteDatasource(this._dio);

  /// Every product matching [search], across all pages (a catalogue is a few
  /// hundred rows; the cap only stops a misbehaving server looping forever).
  Future<List<ProductData>> list({String? search}) async {
    const maxPages = 50;
    try {
      final products = <ProductData>[];
      String? cursor;
      for (var page = 0; page < maxPages; page++) {
        final res = await _dio.get(
          ApiEndpoints.products,
          queryParameters: {
            if (search != null && search.trim().isNotEmpty)
              'search': search.trim(),
            'limit': 100,
            if (cursor != null) 'cursor': cursor,
          },
        );
        final raw = res.data;
        if (raw is! Map || raw['data'] is! List) break;
        products.addAll(
          (raw['data'] as List).whereType<Map>().map(
            (e) => ProductData.fromJson(e.cast<String, dynamic>()),
          ),
        );
        cursor = CursorPage.cursorFromMeta(raw.cast<String, dynamic>());
        if (cursor == null) break;
      }
      return products;
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
        data: req.toUpdateJson(),
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
