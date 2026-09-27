import 'package:dio/dio.dart';

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/utils/idempotency_key.dart';
import '../models/supplier_data.dart';
import '../models/supplier_product_data.dart';

class SupplierRemoteDatasource {
  final Dio _dio;
  SupplierRemoteDatasource(this._dio);

  Future<List<SupplierData>> list() async {
    try {
      final res = await _dio.get(
        ApiEndpoints.suppliers,
        queryParameters: {'limit': 100},
      );
      final raw = res.data;
      if (raw is! Map || raw['data'] is! List) return const [];
      return (raw['data'] as List)
          .whereType<Map>()
          .map((e) => SupplierData.fromJson(e.cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<SupplierData> create({
    required String name,
    String? email,
    String? phone,
    String? address,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.suppliers,
        data: {
          'name': name,
          if (email != null) 'email': email,
          if (phone != null) 'phone': phone,
          if (address != null) 'address': address,
        },
        options: Options(
          headers: {'Idempotency-Key': generateIdempotencyKey()},
        ),
      );
      return SupplierData.fromJson((res.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<SupplierData> update(
    String id, {
    required String name,
    String? email,
    String? phone,
    String? address,
  }) async {
    try {
      final res = await _dio.patch(
        ApiEndpoints.supplier(id),
        data: {
          'name': name,
          'email': email,
          'phone': phone,
          'address': address,
        },
      );
      return SupplierData.fromJson((res.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<void> destroy(String id) async {
    try {
      await _dio.delete(ApiEndpoints.supplier(id));
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<List<SupplierProductData>> listProducts(String supplierId) async {
    try {
      final res = await _dio.get(ApiEndpoints.supplierProducts(supplierId));
      final raw = res.data;
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => SupplierProductData.fromJson(e.cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<SupplierProductData> attachProduct(
    String supplierId, {
    required String productId,
    String? supplierReference,
    int? packSize,
    double? price,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.supplierProducts(supplierId),
        data: {
          'product_id': productId,
          if (supplierReference != null)
            'supplier_reference': supplierReference,
          if (packSize != null) 'pack_size': packSize,
          if (price != null) 'price': price,
        },
        options: Options(
          headers: {'Idempotency-Key': generateIdempotencyKey()},
        ),
      );
      return SupplierProductData.fromJson(
          (res.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }
}
