import 'package:dio/dio.dart';

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/utils/idempotency_key.dart';
import '../models/goods_receipt_data.dart';
import '../models/purchase_order_data.dart';
import '../models/supplier_data.dart';

class PurchaseRemoteDatasource {
  final Dio _dio;
  PurchaseRemoteDatasource(this._dio);

  Future<List<PurchaseOrderData>> listOrders({String? cursor}) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.purchaseOrders,
        queryParameters: {
          if (cursor != null) 'cursor': cursor,
          'per_page': 30,
        },
      );
      final raw = res.data;
      if (raw is! Map || raw['data'] is! List) return const [];
      return (raw['data'] as List)
          .whereType<Map>()
          .map((e) => PurchaseOrderData.fromJson(e.cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<PurchaseOrderData> show(String id) async {
    try {
      final res = await _dio.get(ApiEndpoints.purchaseOrder(id));
      return PurchaseOrderData.fromJson(
        (res.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<PurchaseOrderData> create({
    required String supplierId,
    required List<Map<String, dynamic>> lines,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.purchaseOrders,
        data: {'supplier_id': supplierId, 'lines': lines},
        options: Options(
          headers: {'Idempotency-Key': generateIdempotencyKey()},
        ),
      );
      return PurchaseOrderData.fromJson(
        (res.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<PurchaseOrderData> markOrdered(String id) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.purchaseOrderOrder(id),
        options: Options(
          headers: {'Idempotency-Key': generateIdempotencyKey()},
        ),
      );
      return PurchaseOrderData.fromJson(
        (res.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<PurchaseOrderData> cancel(String id, {String? reason}) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.purchaseOrderCancel(id),
        data: {if (reason != null) 'reason': reason},
        options: Options(
          headers: {'Idempotency-Key': generateIdempotencyKey()},
        ),
      );
      return PurchaseOrderData.fromJson(
        (res.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<GoodsReceiptData> receive({
    required String poId,
    required String locationId,
    required List<Map<String, dynamic>> lines,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.purchaseOrderReceipts(poId),
        data: {'location_id': locationId, 'lines': lines},
        options: Options(
          headers: {'Idempotency-Key': generateIdempotencyKey()},
        ),
      );
      return GoodsReceiptData.fromJson(
        (res.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<List<SupplierData>> listSuppliers() async {
    try {
      final res = await _dio.get(
        ApiEndpoints.suppliers,
        queryParameters: {'per_page': 100},
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
}
