import 'package:dio/dio.dart';

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/network/cursor_page.dart';
import '../../../../core/utils/idempotency_key.dart';
import '../models/inventory_count_data.dart';

/// Inventory sessions are live by nature: the expected quantity is read from
/// the server at the moment of counting, so none of this is queued offline.
class InventoryCountRemoteDatasource {
  final Dio _dio;
  InventoryCountRemoteDatasource(this._dio);

  Options _write() =>
      Options(headers: {'Idempotency-Key': generateIdempotencyKey()});

  Map<String, dynamic> _map(Object? raw) {
    if (raw is! Map) throw const FormatException('Réponse invalide.');
    return raw.cast<String, dynamic>();
  }

  Future<CursorPage<InventoryCountSummary>> list({
    String? status,
    String? cursor,
  }) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.inventoryCounts,
        queryParameters: {
          'limit': 20,
          if (status != null) 'filter[status]': status,
          if (cursor != null) 'cursor': cursor,
        },
      );
      final raw = _map(res.data);
      final data = raw['data'];
      return CursorPage(
        items: data is List
            ? data
                  .whereType<Map>()
                  .map(
                    (e) => InventoryCountSummary.fromJson(
                      e.cast<String, dynamic>(),
                    ),
                  )
                  .toList()
            : const [],
        nextCursor: CursorPage.cursorFromMeta(raw),
      );
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<InventoryCountDetail> show(String id) async {
    try {
      final res = await _dio.get(ApiEndpoints.inventoryCount(id));
      return InventoryCountDetail.fromJson(_map(res.data));
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<InventoryCountDetail> open({
    required String locationId,
    String? note,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.inventoryCounts,
        data: {
          'location_id': locationId,
          if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        },
        options: _write(),
      );
      return InventoryCountDetail.fromJson(_map(res.data));
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<InventoryCountLine> recordLine({
    required String countId,
    required String batchId,
    required int countedQty,
  }) async {
    try {
      final res = await _dio.put(
        ApiEndpoints.inventoryCountLine(countId, batchId),
        data: {'counted_qty': countedQty},
        options: _write(),
      );
      return InventoryCountLine.fromJson(_map(res.data));
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<InventoryCountDetail> close(
    String id, {
    required bool acknowledgeUncounted,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.inventoryCountClose(id),
        data: {'acknowledge_uncounted': acknowledgeUncounted},
        options: _write(),
      );
      return InventoryCountDetail.fromJson(_map(res.data));
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<InventoryCountDetail> cancel(
    String id, {
    required String reason,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.inventoryCountCancel(id),
        data: {'reason': reason.trim()},
        options: _write(),
      );
      return InventoryCountDetail.fromJson(_map(res.data));
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }
}
