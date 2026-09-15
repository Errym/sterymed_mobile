import 'package:dio/dio.dart';

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/errors/error_mapper.dart';
import '../models/label_scan_result.dart';

class LabelRemoteDatasource {
  final Dio _dio;
  LabelRemoteDatasource(this._dio);

  Future<LabelScanResult> fetchByCode(String code) async {
    try {
      final response = await _dio.get(ApiEndpoints.labelByCode(code));
      return LabelScanResult.fromJson(
        (response.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }
}
