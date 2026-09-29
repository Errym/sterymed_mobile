import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/errors/api_exception.dart';

/// Downloads a completed export archive to a local temp file so the client can
/// actually retrieve the ZIP (MVP brief). Uses a *bare* Dio (no auth/base-URL
/// interceptors): the export download URL is a fully-qualified, presigned
/// object-storage link, not a `/v1` API route, so it must not carry the app's
/// bearer token or be rewritten against the API base URL.
class ExportDownloadService {
  final Dio _dio;
  ExportDownloadService(this._dio);

  Future<File> download({
    required String url,
    required String suggestedFileName,
  }) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$suggestedFileName');
      await _dio.download(url, file.path);
      return file;
    } on DioException catch (e) {
      throw ApiException(
        code: 'download_failed',
        message: 'Téléchargement impossible. Vérifiez votre connexion.',
        statusCode: e.response?.statusCode,
      );
    }
  }
}
