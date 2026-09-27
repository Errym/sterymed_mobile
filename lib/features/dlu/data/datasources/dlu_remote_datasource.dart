import 'package:dio/dio.dart';

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/utils/idempotency_key.dart';
import '../models/dlu_rule_data.dart';

class DluRemoteDatasource {
  final Dio _dio;
  DluRemoteDatasource(this._dio);

  Future<List<DluRuleData>> list() async {
    try {
      final res = await _dio.get(ApiEndpoints.dluRules);
      // Response is a BARE array, not { data: [...] }
      final raw = res.data;
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => DluRuleData.fromJson(e.cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<DluRuleData> create({
    required String packagingType,
    required String storageCondition,
    required int shelfLifeDays,
    required String reason,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.dluRules,
        data: {
          'packaging_type': packagingType,
          'storage_condition': storageCondition,
          'shelf_life_days': shelfLifeDays,
          'reason': reason,
        },
        options: Options(
          headers: {'Idempotency-Key': generateIdempotencyKey()},
        ),
      );
      return DluRuleData.fromJson((res.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<DluRuleData> update(
    String id, {
    required String packagingType,
    required String storageCondition,
    required int shelfLifeDays,
    required String reason,
  }) async {
    try {
      final res = await _dio.patch(
        ApiEndpoints.dluRule(id),
        data: {
          'packaging_type': packagingType,
          'storage_condition': storageCondition,
          'shelf_life_days': shelfLifeDays,
          'reason': reason,
        },
      );
      return DluRuleData.fromJson((res.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<void> destroy(String id) async {
    try {
      await _dio.delete(ApiEndpoints.dluRule(id));
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }
}
