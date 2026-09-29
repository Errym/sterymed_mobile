// TASK verification (unit): ExportDownloadService.download must actually write
// the archive to the temp dir and return the File — not just hand back a URL.
// path_provider has no test double, so we mock its real platform channel
// (plugins.flutter.io/path_provider, method getTemporaryDirectory) directly,
// pointing it at a throwaway system-temp dir. Dio is mocked via the shared
// MockDio; we stub `download(url, savePath)` to write bytes to savePath the
// same way the real plugin would, then assert the file exists on disk.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/errors/api_exception.dart';
import 'package:steriymed_mobile/features/reporting/data/services/export_download_service.dart';

import '../../../mocks/mock_dio.dart';

const _pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockDio dio;
  late ExportDownloadService service;
  late Directory tempRoot;

  setUpAll(() {
    registerFallbackValue(Options());
  });

  setUp(() async {
    dio = MockDio();
    service = ExportDownloadService(dio);
    tempRoot = await Directory.systemTemp.createTemp('export_dl_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, (call) async {
      if (call.method == 'getTemporaryDirectory') return tempRoot.path;
      return null;
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, null);
    if (tempRoot.existsSync()) {
      await tempRoot.delete(recursive: true);
    }
  });

  test('download writes the file to the temp dir and returns it', () async {
    // The real Dio.download writes the response body to savePath. Emulate that
    // side effect so the service can hand back a File that actually exists.
    when(() => dio.download(any(), any())).thenAnswer((invocation) async {
      final savePath = invocation.positionalArguments[1] as String;
      await File(savePath).writeAsBytes([0x50, 0x4b, 0x03, 0x04]); // "PK.." ZIP
      return Response<dynamic>(
        requestOptions: RequestOptions(path: savePath),
        statusCode: 200,
      );
    });

    final file = await service.download(
      url: 'https://storage.example.com/exports/abc.zip?sig=xyz',
      suggestedFileName: 'steriymed-export-abcdef12.zip',
    );

    expect(file.existsSync(), isTrue);
    expect(file.path, '${tempRoot.path}/steriymed-export-abcdef12.zip');
    expect(await file.readAsBytes(), [0x50, 0x4b, 0x03, 0x04]);
    verify(
      () => dio.download(
        'https://storage.example.com/exports/abc.zip?sig=xyz',
        '${tempRoot.path}/steriymed-export-abcdef12.zip',
      ),
    ).called(1);
  });

  test('download maps a DioException to a French download_failed ApiException',
      () async {
    when(() => dio.download(any(), any())).thenThrow(
      dioError(statusCode: 503),
    );

    expect(
      () => service.download(
        url: 'https://storage.example.com/exports/abc.zip',
        suggestedFileName: 'steriymed-export-abcdef12.zip',
      ),
      throwsA(
        isA<ApiException>()
            .having((e) => e.code, 'code', 'download_failed')
            .having((e) => e.statusCode, 'statusCode', 503)
            .having(
              (e) => e.message,
              'message',
              'Téléchargement impossible. Vérifiez votre connexion.',
            ),
      ),
    );
  });
}
