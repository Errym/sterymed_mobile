import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/errors/api_exception.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/network/cursor_page.dart';
import '../../../../core/utils/idempotency_key.dart';
import '../models/control_test_data.dart';
import '../models/cycle_attachment_data.dart';
import '../models/cycle_data.dart';
import '../models/cycle_item_data.dart';
import '../models/cycle_release_data.dart';

class CycleRemoteDatasource {
  final Dio _dio;
  CycleRemoteDatasource(this._dio);

  Future<CursorPage<CycleData>> list({String? cursor}) async {
    try {
      final res = await _dio.get(ApiEndpoints.cycles, queryParameters: {
        if (cursor != null) 'cursor': cursor,
        'limit': 20,
      });
      final json = (res.data as Map).cast<String, dynamic>();
      final items = (json['data'] as List)
          .map((e) => CycleData.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      return CursorPage(items: items, nextCursor: CursorPage.cursorFromMeta(json));
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

  /// The stored release decision (who, when, why), or null while the cycle
  /// has none (the server answers 404 until it is released or rejected).
  Future<CycleReleaseData?> getRelease(String cycleId) async {
    try {
      final res = await _dio.get(ApiEndpoints.cycleRelease(cycleId));
      return CycleReleaseData.fromJson(
        (res.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
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

  /// Edits an item in place (PATCH). Only the keys in [changes] are touched:
  /// an item keeps its id, position and batch link unless told otherwise.
  Future<CycleItemData> updateItem(
    String cycleId,
    String itemId,
    Map<String, dynamic> changes,
  ) async {
    try {
      final res = await _dio.patch(
        ApiEndpoints.cycleItem(cycleId, itemId),
        data: changes,
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

  // -------------------------------------------------------------------------
  // Labels — a released cycle has no scannable label until this is called
  // once (backend enforces exactly-once via CYCLE_LABELS_ALREADY_GENERATED).
  // -------------------------------------------------------------------------

  Future<int> countLabels(String cycleId) async {
    try {
      final res = await _dio.get(ApiEndpoints.cycleLabels(cycleId));
      return (res.data as List).length;
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<int> generateLabels(
    String cycleId, {
    required String packagingType,
    required String storageCondition,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.cycleLabels(cycleId),
        data: {
          'packaging_type': packagingType,
          'storage_condition': storageCondition,
        },
        options:
            Options(headers: {'Idempotency-Key': generateIdempotencyKey()}),
      );
      return (res.data as List).length;
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  // -------------------------------------------------------------------------
  // Upload. One path for every platform: a JSON body carrying the file as
  // base64 (`POST /cycles/{id}/attachments-base64`). The multipart route
  // answers 500 behind FrankenPHP/Octane workers (BUG-001), and a JSON body
  // lets the idempotency layer reuse the same key when a lost answer is
  // retried, so a retry cannot attach the photo twice.
  // -------------------------------------------------------------------------
  static const maxAttachmentBytes = 10 * 1024 * 1024;

  Future<CycleAttachmentData> uploadAttachment({
    required String cycleId,
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
    void Function(int sent, int total)? onProgress,
  }) async {
    if (bytes.isEmpty) {
      throw const ApiException(code: 'upload_invalid', message: 'Fichier vide.');
    }
    if (bytes.length > maxAttachmentBytes) {
      throw const ApiException(
        code: 'upload_invalid',
        message: 'Fichier trop volumineux (10 Mo maximum).',
      );
    }
    try {
      final res = await _dio.post(
        ApiEndpoints.cycleAttachmentsBase64(cycleId),
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

  Future<void> deleteAttachment(String cycleId, String attachmentId) async {
    try {
      await _dio.delete(
        ApiEndpoints.cycleAttachment(cycleId, attachmentId),
      );
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }
}
