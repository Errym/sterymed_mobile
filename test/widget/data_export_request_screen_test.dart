// Tapping download resolves the presigned URL, saves it as a real, uniquely
// named file, then offers Ouvrir / Partager. Every failure is a French message.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/errors/api_exception.dart';
import 'package:steriymed_mobile/core/files/file_export_service.dart';
import 'package:steriymed_mobile/di/di.dart';
import 'package:steriymed_mobile/features/reporting/data/models/export_request_data.dart';
import 'package:steriymed_mobile/features/reporting/data/repositories/export_repository.dart';
import 'package:steriymed_mobile/features/reporting/presentation/screens/data_export_request_screen.dart';

import '../helpers/pump_app.dart';

class _MockRepo extends Mock implements ExportRepository {}

class _MockFiles extends Mock implements FileExportService {}

class _MockHandoff extends Mock implements FileHandoff {}

void main() {
  late _MockRepo repo;
  late _MockFiles files;
  late _MockHandoff handoff;

  ExportRequestData export(String status) => ExportRequestData(
        id: 'abcdef12-3456-7890-aaaa-bbbbbbbbbbbb',
        status: status,
        requestedByName: 'Dr Test',
        requestedAt: DateTime(2026, 9, 20, 14, 30),
        sizeBytes: 2 * 1024 * 1024,
      );

  void register<T extends Object>(T v) {
    if (getIt.isRegistered<T>()) getIt.unregister<T>();
    getIt.registerSingleton<T>(v);
  }

  setUpAll(() => registerFallbackValue(File('fallback')));

  setUp(() {
    repo = _MockRepo();
    files = _MockFiles();
    handoff = _MockHandoff();
    register<ExportRepository>(repo);
    register<FileExportService>(files);
    register<FileHandoff>(handoff);
  });

  tearDown(() {
    getIt.unregister<ExportRepository>();
    getIt.unregister<FileExportService>();
    getIt.unregister<FileHandoff>();
  });

  testWidgets('download saves a file then offers Ouvrir and Partager',
      (tester) async {
    final saved = File('${Directory.systemTemp.path}/steriymed-export-x.zip');
    when(() => repo.list(forceRefresh: any(named: 'forceRefresh')))
        .thenAnswer((_) async => [export('completed')]);
    when(() => repo.downloadUrl(any()))
        .thenAnswer((_) async => 'https://storage.example.com/e/abc.zip?sig=x');
    when(() => files.saveFromUrl(
          any(),
          baseName: any(named: 'baseName'),
          extension: any(named: 'extension'),
        )).thenAnswer((_) async => saved);
    when(() => handoff.open(any()))
        .thenAnswer((_) async => HandoffResult.opened);

    await pumpApp(tester, const DataExportRequestScreen());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Télécharger l\'archive ZIP'));
    await tester.pumpAndSettle();

    verify(() => files.saveFromUrl(
          'https://storage.example.com/e/abc.zip?sig=x',
          baseName: 'steriymed-export-abcdef12',
          extension: 'zip',
        )).called(1);
    expect(find.byKey(const Key('saved-file-name')), findsOneWidget);
    expect(find.byKey(const Key('saved-file-share')), findsOneWidget);

    await tester.tap(find.byKey(const Key('saved-file-open')));
    await tester.pumpAndSettle();
    verify(() => handoff.open(saved)).called(1);
  });

  testWidgets('with no app able to open it the user is told to share instead',
      (tester) async {
    when(() => repo.list(forceRefresh: any(named: 'forceRefresh')))
        .thenAnswer((_) async => [export('completed')]);
    when(() => repo.downloadUrl(any())).thenAnswer((_) async => 'https://s/x');
    when(() => files.saveFromUrl(
          any(),
          baseName: any(named: 'baseName'),
          extension: any(named: 'extension'),
        )).thenAnswer((_) async => File('${Directory.systemTemp.path}/x.zip'));
    when(() => handoff.open(any()))
        .thenAnswer((_) async => HandoffResult.noViewer);

    await pumpApp(tester, const DataExportRequestScreen());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Télécharger l\'archive ZIP'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saved-file-open')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Utilisez « Partager »'), findsOneWidget);
  });

  testWidgets('an expired link shows the French reason, nothing is opened',
      (tester) async {
    when(() => repo.list(forceRefresh: any(named: 'forceRefresh')))
        .thenAnswer((_) async => [export('completed')]);
    when(() => repo.downloadUrl(any())).thenAnswer((_) async => 'https://s/x');
    when(() => files.saveFromUrl(
          any(),
          baseName: any(named: 'baseName'),
          extension: any(named: 'extension'),
        )).thenThrow(const ApiException(
      code: 'link_expired',
      message: 'Ce fichier n\'est plus disponible (lien expiré). Redemandez-le.',
    ));

    await pumpApp(tester, const DataExportRequestScreen());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Télécharger l\'archive ZIP'));
    await tester.pumpAndSettle();

    expect(find.textContaining('lien expiré'), findsOneWidget);
    verifyNever(() => handoff.open(any()));
  });

  testWidgets('an expired export offers no download', (tester) async {
    when(() => repo.list(forceRefresh: any(named: 'forceRefresh')))
        .thenAnswer((_) async => [export('expired')]);
    await pumpApp(tester, const DataExportRequestScreen());
    await tester.pumpAndSettle();
    expect(find.text('EXPIRÉ'), findsOneWidget);
    expect(find.text('Télécharger l\'archive ZIP'), findsNothing);
  });

  testWidgets('a failed request for a new export shows the French reason',
      (tester) async {
    when(() => repo.list(forceRefresh: any(named: 'forceRefresh')))
        .thenAnswer((_) async => const []);
    when(() => repo.request()).thenThrow(const ApiException(
      code: 'FORBIDDEN',
      message: 'Action non autorisée.',
      statusCode: 403,
    ));
    await pumpApp(tester, const DataExportRequestScreen());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Demander un Export Complet (ZIP)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('ApiException'), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);
  });
}
