import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/errors/api_exception.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../cycles/data/datasources/cycle_remote_datasource.dart';
import '../../../cycles/data/models/cycle_attachment_data.dart';
import '../../../../core/network/cursor_page.dart';
import '../../../../core/utils/idempotency_key.dart';
import '../models/goods_receipt_data.dart';
import '../models/purchase_order_data.dart';
import '../models/supplier_data.dart';

class PurchaseRemoteDatasource {
  final Dio _dio;
  PurchaseRemoteDatasource(this._dio);

  Future<CursorPage<PurchaseOrderData>> listOrders({
    String? cursor,
    String? status,
  }) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.purchaseOrders,
        queryParameters: {
          if (cursor != null) 'cursor': cursor,
          if (status != null) 'filter[status]': status,
          'limit': 30,
        },
      );
      final raw = res.data;
      if (raw is! Map || raw['data'] is! List) {
        return const CursorPage(items: []);
      }
      final json = raw.cast<String, dynamic>();
      final items = (json['data'] as List)
          .whereType<Map>()
          .map((e) => PurchaseOrderData.fromJson(e.cast<String, dynamic>()))
          .toList();
      return CursorPage(items: items, nextCursor: CursorPage.cursorFromMeta(json));
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

  /// Edits a draft. `lines`, when given, replaces the whole list; with
  /// [clearExpectedAt] the expected date is removed, otherwise [expectedAt]
  /// (when given) replaces it.
  Future<PurchaseOrderData> update(
    String id, {
    List<Map<String, dynamic>>? lines,
    DateTime? expectedAt,
    bool clearExpectedAt = false,
  }) async {
    try {
      final res = await _dio.patch(
        ApiEndpoints.purchaseOrder(id),
        data: {
          if (lines != null) 'lines': lines,
          if (clearExpectedAt) 'expected_at': null,
          if (!clearExpectedAt && expectedAt != null)
            'expected_at': _isoDate(expectedAt),
        },
      );
      return PurchaseOrderData.fromJson(
        (res.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Receipt history of one order, newest first.
  Future<List<GoodsReceiptData>> listReceipts(String poId) async {
    try {
      final res = await _dio.get(ApiEndpoints.purchaseOrderReceipts(poId));
      final raw = res.data;
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => GoodsReceiptData.fromJson(e.cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<List<CycleAttachmentData>> listReceiptAttachments(
    String receiptId,
  ) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.goodsReceiptAttachments(receiptId),
      );
      final raw = res.data;
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => CycleAttachmentData.fromJson(e.cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  /// Uploads the delivery-note photo (or PDF) as base64 JSON, the same
  /// contract as the cycle attachments. The receipt itself is already
  /// committed; a failure here leaves a receipt without proof, never without
  /// stock.
  Future<CycleAttachmentData> uploadReceiptProof({
    required String receiptId,
    required String fileName,
    required Uint8List bytes,
    void Function(int sent, int total)? onProgress,
  }) async {
    if (bytes.isEmpty) {
      throw const ApiException(code: 'upload_invalid', message: 'Fichier vide.');
    }
    if (bytes.length > CycleRemoteDatasource.maxAttachmentBytes) {
      throw const ApiException(
        code: 'upload_invalid',
        message: 'Fichier trop volumineux (10 Mo maximum).',
      );
    }
    try {
      final res = await _dio.post(
        ApiEndpoints.goodsReceiptAttachmentsBase64(receiptId),
        data: {'file_name': fileName, 'file_data': base64Encode(bytes)},
        onSendProgress: onProgress,
      );
      return CycleAttachmentData.fromJson(
        (res.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<PurchaseOrderData> create({
    required String supplierId,
    required List<Map<String, dynamic>> lines,
    DateTime? expectedAt,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.purchaseOrders,
        data: {
          'supplier_id': supplierId,
          'lines': lines,
          if (expectedAt != null) 'expected_at': _isoDate(expectedAt),
        },
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
}
