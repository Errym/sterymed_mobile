import 'package:dio/dio.dart';

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/utils/idempotency_key.dart';
import '../models/supplier_data.dart';

class SupplierRemoteDatasource {
  final Dio _dio;
  SupplierRemoteDatasource(this._dio);

  Future<List<SupplierData>> list() async {
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
}
