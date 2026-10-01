import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/config/env.dart';
import '../../../../core/errors/api_exception.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/network/cursor_page.dart';
import '../../../../core/network/interceptors/idempotency_interceptor.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../../core/utils/idempotency_key.dart';
import '../../../../di/di.dart';
import '../models/laboratory_data.dart';
import '../models/prosthetic_case_attachment_data.dart';
import '../models/prosthetic_case_data.dart';
import '../models/prosthetic_case_status_history_data.dart';
import '../models/prosthetic_dashboard_data.dart';

class ProstheticRemoteDatasource {
  final Dio _dio;
  ProstheticRemoteDatasource(this._dio);

  Future<ProstheticDashboardData> dashboard() async {
    try {
      final res = await _dio.get(ApiEndpoints.prostheticDashboard);
      return ProstheticDashboardData.fromJson(
        (res.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<CursorPage<ProstheticCaseData>> list({
    String? cursor,
    String? patientReference,
    String? practitionerId,
    String? laboratoryId,
    String? workType,
    String? status,
    String? from,
    String? to,
  }) async {
    try {
      final res = await _dio.get(ApiEndpoints.prostheticCases, queryParameters: {
        if (cursor != null) 'cursor': cursor,
        if (patientReference != null && patientReference.isNotEmpty)
          'patient_reference': patientReference,
        if (practitionerId != null) 'practitioner_id': practitionerId,
        if (laboratoryId != null) 'laboratory_id': laboratoryId,
        if (workType != null) 'work_type': workType,
        if (status != null) 'status': status,
        if (from != null) 'from': from,
        if (to != null) 'to': to,
        'limit': 20,
      });
      return _parsePage(res.data);
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<CursorPage<ProstheticCaseData>> waitingForPlacement({
    String? cursor,
  }) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.prostheticWaitingPlacement,
        queryParameters: {
          if (cursor != null) 'cursor': cursor,
          'limit': 20,
        },
      );
      return _parsePage(res.data);
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<ProstheticCaseData> show(String id) async {
    try {
      final res = await _dio.get(ApiEndpoints.prostheticCase(id));
      return ProstheticCaseData.fromJson(
        (res.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<ProstheticCaseData> create(Map<String, dynamic> data) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.prostheticCases,
        data: data,
        options: Options(
          headers: {'Idempotency-Key': generateIdempotencyKey()},
        ),
      );
      return ProstheticCaseData.fromJson(
        (res.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<ProstheticCaseData> update(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      final res = await _dio.patch(ApiEndpoints.prostheticCase(id), data: data);
      return ProstheticCaseData.fromJson(
        (res.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<ProstheticCaseData> changeStatus(
    String id, {
    required String status,
    String? note,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.prostheticCaseStatus(id),
        data: {'status': status, if (note != null && note.isNotEmpty) 'note': note},
        options: Options(
          headers: {'Idempotency-Key': generateIdempotencyKey()},
        ),
      );
      return ProstheticCaseData.fromJson(
        (res.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<List<ProstheticCaseStatusHistoryData>> statusHistory(
    String id,
  ) async {
    try {
      final res = await _dio.get(ApiEndpoints.prostheticCaseStatusHistory(id));
      return (res.data as List)
          .whereType<Map>()
          .map((e) => ProstheticCaseStatusHistoryData.fromJson(
              e.cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<List<ProstheticCaseAttachmentData>> listAttachments(
    String id,
  ) async {
    try {
      final res = await _dio.get(ApiEndpoints.prostheticCaseAttachments(id));
      return (res.data as List)
          .whereType<Map>()
          .map((e) => ProstheticCaseAttachmentData.fromJson(
              e.cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  /// Same web/native split as `CycleRemoteDatasource.uploadAttachment` —
  /// Dio's multipart doesn't survive a browser's fetch layer, so web goes
  /// through `package:http`'s `MultipartRequest` instead.
  Future<ProstheticCaseAttachmentData> uploadAttachment({
    required String caseId,
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
  }) async {
    final effectiveMime = (mimeType != null && mimeType.isNotEmpty)
        ? mimeType
        : 'application/octet-stream';

    if (kIsWeb) {
      return _uploadOnWeb(
        caseId: caseId,
        fileName: fileName,
        bytes: bytes,
        mimeType: effectiveMime,
      );
    }

    try {
      final file = MultipartFile.fromBytes(
        bytes,
        filename: fileName,
        contentType: DioMediaType.parse(effectiveMime),
      );
      final res = await _dio.post(
        ApiEndpoints.prostheticCaseAttachments(caseId),
        data: FormData.fromMap({'file': file}),
        // A retried upload of the same file reuses its key, so the server
        // replays the first answer instead of attaching the file twice.
        options: Options(
          extra: {
            IdempotencyInterceptor.callerFingerprintKey:
                'upload:$caseId:$fileName:${bytes.length}',
          },
        ),
      );
      return ProstheticCaseAttachmentData.fromJson(
        (res.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<ProstheticCaseAttachmentData> _uploadOnWeb({
    required String caseId,
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
    final uri =
        Uri.parse('$base${ApiEndpoints.prostheticCaseAttachments(caseId)}');

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

    final streamed = await req.send();
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode >= 400) {
      String msg = 'Échec de l\'envoi (HTTP ${streamed.statusCode}).';
      try {
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        final err = decoded['error'];
        if (err is Map && err['message'] != null) {
          msg = err['message'].toString();
        }
      } catch (_) {}
      throw ApiException(
        code: 'upload_failed',
        message: msg,
        statusCode: streamed.statusCode,
      );
    }

    return ProstheticCaseAttachmentData.fromJson(
      (jsonDecode(body) as Map).cast<String, dynamic>(),
    );
  }

  Future<void> deleteAttachment(String caseId, String attachmentId) async {
    try {
      await _dio.delete(ApiEndpoints.prostheticCaseAttachment(caseId, attachmentId));
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<List<LaboratoryData>> listLaboratories() async {
    try {
      final res = await _dio.get(ApiEndpoints.laboratories);
      return (res.data as List)
          .whereType<Map>()
          .map((e) => LaboratoryData.fromJson(e.cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<LaboratoryData> createLaboratory(Map<String, dynamic> data) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.laboratories,
        data: data,
        options: Options(
          headers: {'Idempotency-Key': generateIdempotencyKey()},
        ),
      );
      return LaboratoryData.fromJson((res.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<LaboratoryData> updateLaboratory(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      final res = await _dio.patch(ApiEndpoints.laboratory(id), data: data);
      return LaboratoryData.fromJson((res.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  CursorPage<ProstheticCaseData> _parsePage(dynamic raw) {
    final json = (raw as Map).cast<String, dynamic>();
    final items = (json['data'] as List)
        .whereType<Map>()
        .map((e) => ProstheticCaseData.fromJson(e.cast<String, dynamic>()))
        .toList();
    return CursorPage(items: items, nextCursor: CursorPage.cursorFromMeta(json));
  }
}
