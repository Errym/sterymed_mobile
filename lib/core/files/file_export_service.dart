import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../errors/api_exception.dart';
import '../errors/error_mapper.dart';

/// What happened when a saved file was handed to the device.
enum HandoffResult { opened, noViewer, failed }

/// Opens or shares a saved file. A seam, so tests never touch a platform
/// channel.
abstract class FileHandoff {
  Future<HandoffResult> open(File file);
  Future<void> share(File file, {String? text});
}

class DeviceFileHandoff implements FileHandoff {
  const DeviceFileHandoff();

  @override
  Future<HandoffResult> open(File file) async {
    final r = await OpenFilex.open(file.path);
    return switch (r.type) {
      ResultType.done => HandoffResult.opened,
      ResultType.noAppToOpen => HandoffResult.noViewer,
      _ => HandoffResult.failed,
    };
  }

  @override
  Future<void> share(File file, {String? text}) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: text),
    );
  }
}

/// Saves what the server sends (a PDF dossier, a CSV, an archive) as a real
/// file the clinic keeps, and hands it to the device to open or share.
///
/// * Two exports never overwrite each other: every file name carries the
///   moment it was saved, and a name that is still taken gets a counter.
/// * Failures are French and honest: no right to export, a link that has
///   expired, no network, nothing silently saved.
class FileExportService {
  final Dio _authed;
  final Dio _bare;
  final Future<Directory> Function() _directory;
  final DateTime Function() _now;

  FileExportService({
    required Dio authenticated,
    required Dio bare,
    Future<Directory> Function()? directory,
    DateTime Function()? now,
  })  : _authed = authenticated,
        // ignore: prefer_initializing_formals
        _bare = bare,
        _directory = directory ?? _defaultDirectory,
        _now = now ?? DateTime.now;

  static Future<Directory> _defaultDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/exports');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// `evidence-20261002-143005.csv`, never the same twice.
  static String uniqueName(
    String base,
    String extension,
    DateTime at, {
    bool Function(String name)? taken,
  }) {
    final stamp = DateFormat('yyyyMMdd-HHmmss').format(at);
    final clean = base.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '-');
    var name = '$clean-$stamp.$extension';
    var n = 2;
    while (taken != null && taken(name)) {
      name = '$clean-$stamp-$n.$extension';
      n++;
    }
    return name;
  }

  Future<File> _target(String base, String extension) async {
    final dir = await _directory();
    final name = uniqueName(
      base,
      extension,
      _now(),
      taken: (n) => File('${dir.path}/$n').existsSync(),
    );
    return File('${dir.path}/$name');
  }

  /// A file behind an authenticated API route (`GET /v1/...`).
  Future<File> saveFromApi(
    String path, {
    Map<String, dynamic>? query,
    required String baseName,
    required String extension,
  }) async {
    try {
      final res = await _authed.get<List<int>>(
        path,
        queryParameters: query,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = res.data;
      if (bytes == null || bytes.isEmpty) {
        throw const ApiException(
          code: 'empty_file',
          message: 'Le fichier reçu est vide. Réessayez.',
        );
      }
      final file = await _target(baseName, extension);
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } on DioException catch (e) {
      throw _failure(e);
    }
  }

  /// A presigned object-storage link: no bearer token, no API base URL.
  Future<File> saveFromUrl(
    String url, {
    required String baseName,
    required String extension,
  }) async {
    if (url.trim().isEmpty) {
      throw const ApiException(
        code: 'link_unavailable',
        message: 'Le lien de téléchargement n\'est pas disponible. '
            'Redemandez le fichier.',
      );
    }
    final file = await _target(baseName, extension);
    try {
      await _bare.download(url, file.path);
      return file;
    } on DioException catch (e) {
      // Never leave half a file behind under a name that looks complete.
      if (file.existsSync()) file.deleteSync();
      throw _failure(e);
    }
  }

  ApiException _failure(DioException e) {
    final status = e.response?.statusCode;
    if (status == 403) {
      return const ApiException(
        code: 'FORBIDDEN',
        message: 'Votre rôle ne permet pas cet export.',
        statusCode: 403,
      );
    }
    if (status == 404 || status == 410) {
      return ApiException(
        code: 'link_expired',
        message: 'Ce fichier n\'est plus disponible (lien expiré). '
            'Redemandez-le.',
        statusCode: status,
      );
    }
    // A JSON error envelope arrives as bytes when the request asked for
    // bytes: decode it so the server's own code and reason are not lost.
    final data = e.response?.data;
    if (data is List<int>) {
      try {
        final decoded = jsonDecode(utf8.decode(data));
        if (decoded is Map<String, dynamic>) {
          e.response!.data = decoded;
        }
      } catch (_) {
        // Not JSON: fall through to the status-based message.
      }
    }
    return ErrorMapper.fromDio(e);
  }
}
