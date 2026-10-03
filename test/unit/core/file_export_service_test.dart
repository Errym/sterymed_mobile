// Phase 7 / T7.4: exports are real files that never overwrite each other, and
// every failure is honest and French.

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/errors/api_exception.dart';
import 'package:steriymed_mobile/core/files/file_export_service.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late Directory dir;
  late _MockDio authed;
  late _MockDio bare;
  late DateTime clock;
  late FileExportService service;

  setUpAll(() {
    registerFallbackValue(Options());
  });

  setUp(() {
    dir = Directory.systemTemp.createTempSync('export_test_');
    authed = _MockDio();
    bare = _MockDio();
    clock = DateTime(2026, 10, 2, 14, 30, 5);
    service = FileExportService(
      authenticated: authed,
      bare: bare,
      directory: () async => dir,
      now: () => clock,
    );
  });

  tearDown(() => dir.deleteSync(recursive: true));

  void stubBytes(List<int> bytes) {
    when(() => authed.get<List<int>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        )).thenAnswer((_) async => Response<List<int>>(
          requestOptions: RequestOptions(path: ''),
          data: bytes,
          statusCode: 200,
        ));
  }

  void stubFailure(int status, {Object? body}) {
    when(() => authed.get<List<int>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        )).thenThrow(DioException(
      requestOptions: RequestOptions(path: ''),
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: RequestOptions(path: ''),
        statusCode: status,
        data: body,
      ),
    ));
  }

  group('names', () {
    test('carry the moment they were saved', () {
      expect(
        FileExportService.uniqueName('preuves', 'csv', clock),
        'preuves-20261002-143005.csv',
      );
    });

    test('unsafe characters never reach the file system', () {
      expect(
        FileExportService.uniqueName('a/b c', 'pdf', clock),
        'a-b-c-20261002-143005.pdf',
      );
    });

    test('a name already taken gets a counter instead of being overwritten',
        () {
      final taken = {'x-20261002-143005.pdf', 'x-20261002-143005-2.pdf'};
      expect(
        FileExportService.uniqueName('x', 'pdf', clock, taken: taken.contains),
        'x-20261002-143005-3.pdf',
      );
    });
  });

  group('saveFromApi', () {
    test('writes the bytes to a real file', () async {
      stubBytes(utf8.encode('a;b\n1;2\n'));
      final file = await service.saveFromApi('/v1/x',
          baseName: 'preuves', extension: 'csv');
      expect(file.existsSync(), isTrue);
      expect(file.readAsStringSync(), 'a;b\n1;2\n');
      expect(file.path.endsWith('preuves-20261002-143005.csv'), isTrue);
    });

    test('two exports in the same second never overwrite each other',
        () async {
      stubBytes(utf8.encode('first'));
      final a = await service.saveFromApi('/v1/x',
          baseName: 'p', extension: 'csv');
      stubBytes(utf8.encode('second'));
      final b = await service.saveFromApi('/v1/x',
          baseName: 'p', extension: 'csv');
      expect(a.path, isNot(b.path));
      expect(a.readAsStringSync(), 'first');
      expect(b.readAsStringSync(), 'second');
    });

    test('an empty answer is an error, not an empty file', () async {
      stubBytes(const []);
      await expectLater(
        service.saveFromApi('/v1/x', baseName: 'p', extension: 'csv'),
        throwsA(isA<ApiException>()),
      );
      expect(dir.listSync(), isEmpty);
    });

    test('403 says the role may not export', () async {
      stubFailure(403);
      await expectLater(
        service.saveFromApi('/v1/x', baseName: 'p', extension: 'csv'),
        throwsA(isA<ApiException>().having(
            (e) => e.message, 'message', contains('Votre rôle'))),
      );
      expect(dir.listSync(), isEmpty);
    });

    test('404/410 says the file is gone and must be requested again',
        () async {
      stubFailure(410);
      await expectLater(
        service.saveFromApi('/v1/x', baseName: 'p', extension: 'csv'),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', contains('expiré'))),
      );
    });

    test('the server reason in a JSON error body is kept', () async {
      stubFailure(
        422,
        body: utf8.encode(jsonEncode({
          'error': {'code': 'VALIDATION_FAILED', 'message': 'Période invalide.'}
        })),
      );
      await expectLater(
        service.saveFromApi('/v1/x', baseName: 'p', extension: 'csv'),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', 'VALIDATION_FAILED')),
      );
    });

    test('no network is a connection message, nothing saved', () async {
      when(() => authed.get<List<int>>(
            any(),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          )).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.connectionError,
      ));
      await expectLater(
        service.saveFromApi('/v1/x', baseName: 'p', extension: 'csv'),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', contains('Connexion'))),
      );
      expect(dir.listSync(), isEmpty);
    });
  });

  group('saveFromUrl', () {
    test('an empty link is refused without any request', () async {
      await expectLater(
        service.saveFromUrl('  ', baseName: 'z', extension: 'zip'),
        throwsA(isA<ApiException>()),
      );
      verifyZeroInteractions(bare);
    });

    test('a failed download leaves no half file behind', () async {
      when(() => bare.download(any(), any())).thenAnswer((inv) async {
        File(inv.positionalArguments[1] as String).writeAsStringSync('half');
        throw DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.connectionError,
        );
      });
      await expectLater(
        service.saveFromUrl('https://s/x.zip', baseName: 'z', extension: 'zip'),
        throwsA(isA<ApiException>()),
      );
      expect(dir.listSync(), isEmpty);
    });

    test('an expired presigned link says so', () async {
      when(() => bare.download(any(), any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 403,
        ),
      ));
      await expectLater(
        service.saveFromUrl('https://s/x.zip', baseName: 'z', extension: 'zip'),
        throwsA(isA<ApiException>()),
      );
    });

    test('a successful download keeps the file', () async {
      when(() => bare.download(any(), any())).thenAnswer((inv) async {
        File(inv.positionalArguments[1] as String).writeAsStringSync('zip');
        return Response(requestOptions: RequestOptions(path: ''));
      });
      final f = await service.saveFromUrl('https://s/x.zip',
          baseName: 'z', extension: 'zip');
      expect(f.existsSync(), isTrue);
    });
  });
}
