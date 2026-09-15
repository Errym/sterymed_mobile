import 'package:dio/dio.dart';

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/utils/idempotency_key.dart';
import '../models/control_test_data.dart';
import '../models/cycle_attachment_data.dart';
import '../models/cycle_data.dart';
import '../models/cycle_item_data.dart';
import '../models/cycle_release_data.dart';

class CycleRemoteDatasource {
  final Dio _dio;
  CycleRemoteDatasource(this._dio);

  Future<List<CycleData>> list({String? cursor}) async {
    try {
      final res = await _dio.get(ApiEndpoints.cycles, queryParameters: {
        if (cursor != null) 'cursor': cursor,
        'per_page': 20,
      });
      return (res.data['data'] as List)
          .map((e) => CycleData.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<CycleData> show(String id) async {
    try {
      final res = await _dio.get(ApiEndpoints.cycle(id));
      return CycleData.fromJson((res.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<CycleData> create(Map<String, dynamic> payload) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.cycles,
        data: payload,
        options:
            Options(headers: {'Idempotency-Key': generateIdempotencyKey()}),
      );
      return CycleData.fromJson((res.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<CycleData> start(String id) =>
      _transition(ApiEndpoints.cycleStart(id));
  Future<CycleData> complete(String id) =>
      _transition(ApiEndpoints.cycleComplete(id));
  Future<CycleData> submitForRelease(String id) =>
      _transition(ApiEndpoints.cycleSubmit(id));

  Future<CycleData> _transition(String url) async {
    try {
      final res = await _dio.post(
        url,
        options:
            Options(headers: {'Idempotency-Key': generateIdempotencyKey()}),
      );
      return CycleData.fromJson((res.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<CycleReleaseData> release(
    String id, {
    required String decision,
    String? reason,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.cycleRelease(id),
        data: {'decision': decision, if (reason != null) 'reason': reason},
        options:
            Options(headers: {'Idempotency-Key': generateIdempotencyKey()}),
      );
      return CycleReleaseData.fromJson(
          (res.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  // ---- Items ----
  Future<List<CycleItemData>> listItems(String cycleId) async {
    try {
      final res = await _dio.get(ApiEndpoints.cycleItems(cycleId));
      return (res.data as List)
          .map(
              (e) => CycleItemData.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<CycleItemData> addItem(
      String cycleId, Map<String, dynamic> payload) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.cycleItems(cycleId),
        data: payload,
        options:
            Options(headers: {'Idempotency-Key': generateIdempotencyKey()}),
      );
      return CycleItemData.fromJson((res.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<void> deleteItem(String cycleId, String itemId) async {
    try {
      await _dio.delete(ApiEndpoints.cycleItem(cycleId, itemId));
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  // ---- Control tests ----
  Future<List<ControlTestData>> listControlTests(String cycleId) async {
    try {
      final res = await _dio.get(ApiEndpoints.cycleControlTests(cycleId));
      return (res.data as List)
          .map((e) =>
              ControlTestData.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<ControlTestData> addControlTest(
    String cycleId,
    Map<String, dynamic> payload,
  ) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.cycleControlTests(cycleId),
        data: payload,
        options:
            Options(headers: {'Idempotency-Key': generateIdempotencyKey()}),
      );
      return ControlTestData.fromJson(
          (res.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  // ---- Attachments ----
  Future<List<CycleAttachmentData>> listAttachments(String cycleId) async {
    try {
      final res = await _dio.get(ApiEndpoints.cycleAttachments(cycleId));
      return (res.data as List)
          .map((e) =>
              CycleAttachmentData.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<CycleAttachmentData> uploadAttachment(
    String cycleId,
    String filePath,
    String fileName,
  ) async {
    try {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
      });
      final res = await _dio.post(
        ApiEndpoints.cycleAttachments(cycleId),
        data: form,
        options:
            Options(headers: {'Idempotency-Key': generateIdempotencyKey()}),
      );
      return CycleAttachmentData.fromJson(
        (res.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<void> deleteAttachment(String cycleId, int mediaId) async {
    try {
      await _dio.delete(ApiEndpoints.cycleAttachment(cycleId, mediaId));
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }
}
