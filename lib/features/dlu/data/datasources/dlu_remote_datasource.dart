import 'package:dio/dio.dart';

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/errors/error_mapper.dart';
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
}
