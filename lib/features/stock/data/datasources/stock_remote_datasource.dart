import 'package:dio/dio.dart';

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/utils/idempotency_key.dart';
import '../models/stock_level_data.dart';
import '../models/stock_movement_data.dart';

class StockRemoteDatasource {
  final Dio _dio;
  StockRemoteDatasource(this._dio);

  Future<List<StockLevelData>> listLevels({String? search}) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.stockLevels,
        queryParameters: {
          if (search != null && search.trim().isNotEmpty)
            'search': search.trim(),
          'per_page': 100,
        },
      );
      final raw = res.data;
      if (raw is! Map || raw['data'] is! List) return const [];
      return (raw['data'] as List)
          .whereType<Map>()
          .map((e) => StockLevelData.fromJson(e.cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<StockMovementData> issue({
    required String batchId,
    required String locationId,
    required int qty,
    String? reason,
  }) =>
      _postMovement(ApiEndpoints.stockIssue, {
        'batch_id': batchId,
        'location_id': locationId,
        'qty': qty,
        if (reason != null && reason.trim().isNotEmpty)
          'reason': reason.trim(),
      });

  Future<StockMovementData> adjust({
    required String batchId,
    required String locationId,
    required int qty,
    required String reason,
  }) =>
      _postMovement(ApiEndpoints.stockAdjust, {
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
