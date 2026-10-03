import 'package:dio/dio.dart';

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/network/cursor_page.dart';
import '../../../../core/utils/idempotency_key.dart';
import '../models/batch_data.dart';
import '../models/code_lookup.dart';
import '../models/stock_level_data.dart';
import '../models/stock_movement_data.dart';
import '../models/stock_option.dart';

class StockRemoteDatasource {
  final Dio _dio;
  StockRemoteDatasource(this._dio);

  /// Every stock row, all pages: a clinic with more than a page of stock must
  /// not silently lose the rest. [inStockOnly] drops rows with nothing on the
  /// shelf (what a source picker needs).
  Future<List<StockLevelData>> listLevels({
    String? search,
    bool inStockOnly = false,
  }) async {
    try {
      final rows = await _fetchAll(
        ApiEndpoints.stockLevels,
        query: {
          if (search != null && search.trim().isNotEmpty)
            'search': search.trim(),
          if (inStockOnly) 'in_stock': 1,
        },
        pageSize: 200,
      );
      return rows.map(StockLevelData.fromJson).toList();
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  /// Every lot, all pages: supplier, received date, status and the quantity on
  /// hand across all places (`GET /v1/batches`). Lots with nothing left are
  /// included, so a lot can still be traced after it is used up.
  Future<List<BatchData>> listBatches() async {
    try {
      final rows = await _fetchAll(ApiEndpoints.batches, pageSize: 200);
      return rows.map(BatchData.fromJson).toList();
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  /// Every page of a cursor-paginated lookup. The cap only guards against a
  /// misbehaving server looping forever; real clinics stay far below it.
  Future<List<Map<String, dynamic>>> _fetchAll(
    String path, {
    Map<String, dynamic> query = const {},
    int pageSize = 100,
    int maxPages = 50,
  }) async {
    final rows = <Map<String, dynamic>>[];
    String? cursor;
    for (var page = 0; page < maxPages; page++) {
      final res = await _dio.get(
        path,
        queryParameters: {
          ...query,
          'limit': pageSize,
          if (cursor != null) 'cursor': cursor,
        },
      );
      final raw = res.data;
      if (raw is! Map || raw['data'] is! List) break;
      rows.addAll(
        (raw['data'] as List).whereType<Map>().map(
          (e) => e.cast<String, dynamic>(),
        ),
      );
      cursor = CursorPage.cursorFromMeta(raw.cast<String, dynamic>());
      if (cursor == null) break;
    }
    return rows;
  }

  /// The pickable batches and locations, from the dedicated lookup endpoints:
  /// complete (all pages), and independent of stock rows, so a brand-new clinic
  /// with no stock yet still gets its locations for a first delivery.
  ///
  /// Falls back to deriving them from stock levels only when the server does not
  /// have the lookup routes at all (404/405: an older backend), so a newer app
  /// never leaves the user with empty pickers.
  Future<({List<StockOption> batches, List<StockOption> locations})>
  listOptions() async {
    try {
      final results = await Future.wait([
        _fetchAll(ApiEndpoints.locations),
        _fetchAll(ApiEndpoints.batches, query: const {'status': 'active'}),
      ]);
      final locations = results[0].map(_locationOption).toList()
        ..sort((a, b) => a.label.compareTo(b.label));
      final batches = results[1].map(_batchOption).toList()
        ..sort((a, b) => a.label.compareTo(b.label));
      return (batches: batches, locations: locations);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 404 || status == 405) return _listOptionsFromLevels();
      throw ErrorMapper.fromDio(e);
    }
  }

  StockOption _locationOption(Map<String, dynamic> row) {
    final name = (row['name'] ?? '').toString();
    final site = (row['site_name'] ?? '').toString();
    final room = (row['room_name'] ?? '').toString();
    final where = [site, room].where((p) => p.isNotEmpty).join(' / ');
    return StockOption(
      id: row['id'].toString(),
      label: where.isEmpty ? name : '$name · $where',
    );
  }

  StockOption _batchOption(Map<String, dynamic> row) {
    final number = (row['batch_number'] ?? '').toString();
    final product = (row['product_name'] ?? '').toString();
    final qty = row['qty_on_hand'];
    final onHand = qty is num ? ' · ${qty.toInt()} en stock' : '';
    return StockOption(
      id: row['id'].toString(),
      label: 'Lot $number · $product$onHand',
    );
  }

  /// Compatibility only: derives the pickers from the first page of stock
  /// levels. Incomplete by nature (no empty locations, no batches without
  /// stock, first 100 rows), which is why the lookup endpoints replace it.
  Future<({List<StockOption> batches, List<StockOption> locations})>
  _listOptionsFromLevels() async {
    final levels = await listLevels();
    final batches = <String, StockOption>{};
    final locations = <String, StockOption>{};
    for (final l in levels) {
      if (l.batchId != null && l.batchId!.isNotEmpty) {
        batches.putIfAbsent(
          l.batchId!,
          () => StockOption(
            id: l.batchId!,
            label: l.batchNumber != null && l.batchNumber!.isNotEmpty
                ? 'Lot ${l.batchNumber} · ${l.productName}'
                : 'Lot ${l.batchId!.substring(0, 6)} · ${l.productName}',
          ),
        );
      }
      if (l.locationId.isNotEmpty) {
        locations.putIfAbsent(
          l.locationId,
          () => StockOption(
            id: l.locationId,
            label: l.locationName.isNotEmpty
                ? l.locationName
                : 'Emplacement ${l.locationId.substring(0, 6)}',
          ),
        );
      }
    }
    return (
      batches: batches.values.toList()
        ..sort((a, b) => a.label.compareTo(b.label)),
      locations: locations.values.toList()
        ..sort((a, b) => a.label.compareTo(b.label)),
    );
  }

  /// Resolves a scanned or typed product barcode, reference or lot number.
  /// A pure read. The server answers 404 `CODE_NOT_FOUND` when nothing matches.
  Future<CodeLookup> lookupCode(String code) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.codeLookup,
        queryParameters: {'code': code.trim()},
      );
      final raw = res.data;
      if (raw is! Map) throw const FormatException('Réponse invalide.');
      return CodeLookup.fromJson(raw.cast<String, dynamic>());
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<StockMovementData> issue({
    required String batchId,
    required String locationId,
    required int qty,
    String? reason,
  }) => _postMovement(ApiEndpoints.stockIssue, {
    'batch_id': batchId,
    'location_id': locationId,
    'qty': qty,
    if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
  });

  Future<StockMovementData> adjust({
    required String batchId,
    required String locationId,
    required int qty,
    required String reason,
  }) => _postMovement(ApiEndpoints.stockAdjust, {
    'batch_id': batchId,
    'location_id': locationId,
    'qty': qty,
    'reason': reason.trim(),
  });

  Future<StockMovementData> transfer({
    required String batchId,
    required String fromLocationId,
    required String toLocationId,
    required int qty,
    String? reason,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.stockTransfer,
        data: {
          'batch_id': batchId,
          'from_location_id': fromLocationId,
          'to_location_id': toLocationId,
          'qty': qty,
          if (reason != null && reason.trim().isNotEmpty)
            'reason': reason.trim(),
        },
        options: Options(
          headers: {'Idempotency-Key': generateIdempotencyKey()},
        ),
      );
      final raw = res.data;
      if (raw is! Map) {
        throw const FormatException('Réponse de transfert invalide.');
      }
      final debit = raw['debit'];
      if (debit is! Map) {
        throw const FormatException('Réponse de transfert invalide.');
      }
      return StockMovementData.fromJson(debit.cast<String, dynamic>());
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<StockMovementData> _postMovement(
    String path,
    Map<String, dynamic> payload,
  ) async {
    try {
      final res = await _dio.post(
        path,
        data: payload,
        options: Options(
          headers: {'Idempotency-Key': generateIdempotencyKey()},
        ),
      );
      final raw = res.data;
      if (raw is! Map) throw const FormatException('Réponse invalide.');
      return StockMovementData.fromJson(raw.cast<String, dynamic>());
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }
}
