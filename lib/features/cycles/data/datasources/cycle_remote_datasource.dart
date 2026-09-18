import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/config/env.dart';
import '../../../../core/errors/api_exception.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../../core/utils/idempotency_key.dart';
import '../../../../di/di.dart';
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
  // Upload — final version
  //
  // Web (Dio's multipart is broken through browser fetch):
  //   - Use package:http's MultipartRequest → goes through XMLHttpRequest
  //   - Include Idempotency-Key header (backend middleware requires it)
  //
  // Native (Dio's multipart works on iOS/Android):
  //   - Dio's MultipartFile
  //   - Include Idempotency-Key header
  // -------------------------------------------------------------------------
  Future<CycleAttachmentData> uploadAttachment({
    required String cycleId,
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
  }) async {
    final effectiveMime = (mimeType != null && mimeType.isNotEmpty)
        ? mimeType
        : 'application/octet-stream';

    if (kDebugMode) {
      debugPrint('-> UPLOAD kIsWeb=$kIsWeb cycleId=$cycleId '
          'fileName=$fileName bytes=${bytes.length} mime=$effectiveMime');
    }

    if (kIsWeb) {
      return _uploadOnWeb(
        cycleId: cycleId,
        fileName: fileName,
        bytes: bytes,
        mimeType: effectiveMime,
      );
    }

    // Native path.
    try {
      final file = MultipartFile.fromBytes(
        bytes,
        filename: fileName,
        contentType: DioMediaType.parse(effectiveMime),
      );
      final form = FormData.fromMap({'file': file});
      final res = await _dio.post(
        ApiEndpoints.cycleAttachments(cycleId),
        data: form,
        options: Options(
          headers: {'Idempotency-Key': generateIdempotencyKey()},
        ),
      );
      return CycleAttachmentData.fromJson(
        (res.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<CycleAttachmentData> _uploadOnWeb({
    required String cycleId,
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final token = await getIt<TokenStorage>().read();
    if (token == null || token.isEmpty) {
      throw const ApiException(
        code: 'unauthenticated',
        message: 'Session expirée. Veuillez vous reconnecter.',
      );
    }

    final base = Env.apiBaseUrl.endsWith('/')
        ? Env.apiBaseUrl.substring(0, Env.apiBaseUrl.length - 1)
        : Env.apiBaseUrl;

    final uri = Uri.parse('$base${ApiEndpoints.cycleAttachments(cycleId)}');

    final parts = mimeType.split('/');
    final mediaType = parts.length == 2
        ? http.MediaType(parts[0], parts[1])
        : http.MediaType('application', 'octet-stream');

    final req = http.MultipartRequest('POST', uri);
    req.headers['Accept'] = 'application/json';
    req.headers['Authorization'] = 'Bearer $token';
    req.headers['Idempotency-Key'] = generateIdempotencyKey();
    req.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: fileName,
      contentType: mediaType,
    ));

    if (kDebugMode) {
      debugPrint('-> HTTP-UPLOAD uri=$uri file=$fileName bytes=${bytes.length}');
    }

    final streamed = await req.send();
    final body = await streamed.stream.bytesToString();

    if (kDebugMode) {
      debugPrint('<- HTTP-UPLOAD status=${streamed.statusCode}');
      debugPrint('<- HTTP-UPLOAD body=$body');
    }

    if (streamed.statusCode >= 400) {
      String msg = 'Échec de l\'envoi (HTTP ${streamed.statusCode}).';
      try {
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        final err = decoded['error'];
        if (err is Map && err['message'] != null) {
          msg = err['message'].toString();
        }
      } catch (_) {
        // Keep fallback.
      }
      throw ApiException(
        code: 'upload_failed',
        message: msg,
        statusCode: streamed.statusCode,
      );
    }

    final decoded = jsonDecode(body) as Map<String, dynamic>;
    return CycleAttachmentData.fromJson(decoded);
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
