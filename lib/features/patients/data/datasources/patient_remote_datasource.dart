import 'package:dio/dio.dart';

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/errors/error_mapper.dart';
import '../models/patient_data.dart';

class PatientRemoteDatasource {
  final Dio _dio;
  PatientRemoteDatasource(this._dio);

  Future<List<PatientData>> search(String query) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.patients,
        queryParameters: {
          if (query.trim().isNotEmpty) 'search': query.trim(),
          'per_page': 30,
        },
      );
      final list = (response.data['data'] as List)
          .map((e) => PatientData.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      return list;
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }
}
