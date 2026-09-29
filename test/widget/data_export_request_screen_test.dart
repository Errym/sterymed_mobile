// TASK verification (widget): tapping the per-export download button must now
// (a) resolve the presigned URL via ExportRepository.downloadUrl and (b) hand
// that URL to ExportDownloadService.download with the id-derived filename —
// i.e. a real file retrieval, not the old clipboard copy. Both collaborators
// are mocked and registered in the shared GetIt the screen resolves from.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/di/di.dart';
import 'package:steriymed_mobile/features/reporting/data/models/export_request_data.dart';
import 'package:steriymed_mobile/features/reporting/data/repositories/export_repository.dart';
import 'package:steriymed_mobile/features/reporting/data/services/export_download_service.dart';
import 'package:steriymed_mobile/features/reporting/presentation/screens/data_export_request_screen.dart';

import '../helpers/pump_app.dart';

class MockExportRepository extends Mock implements ExportRepository {}

class MockExportDownloadService extends Mock
    implements ExportDownloadService {}

void main() {
  late MockExportRepository repo;
  late MockExportDownloadService downloader;

  final completedExport = ExportRequestData(
    id: 'abcdef12-3456-7890-aaaa-bbbbbbbbbbbb',
    status: 'completed',
    requestedByName: 'Dr Test',
    requestedAt: DateTime(2026, 9, 20, 14, 30),
    sizeBytes: 2 * 1024 * 1024,
  );

  setUp(() {
    repo = MockExportRepository();
    downloader = MockExportDownloadService();
    if (getIt.isRegistered<ExportRepository>()) {
      getIt.unregister<ExportRepository>();
    }
    if (getIt.isRegistered<ExportDownloadService>()) {
      getIt.unregister<ExportDownloadService>();
    }
    getIt.registerSingleton<ExportRepository>(repo);
    getIt.registerSingleton<ExportDownloadService>(downloader);
  });

  tearDown(() {
    getIt.unregister<ExportRepository>();
    getIt.unregister<ExportDownloadService>();
  });

  testWidgets(
    'tapping download resolves the URL then downloads it with the id-based '
    'filename',
    (tester) async {
      when(() => repo.list(forceRefresh: any(named: 'forceRefresh')))
          .thenAnswer((_) async => [completedExport]);
      when(() => repo.downloadUrl(completedExport.id))
          .thenAnswer((_) async => 'https://storage.example.com/e/abc.zip?sig=x');
      when(() => downloader.download(
            url: any(named: 'url'),
            suggestedFileName: any(named: 'suggestedFileName'),
          )).thenAnswer(
        (_) async => File('${Directory.systemTemp.path}/abc.zip'),
      );

      await pumpApp(tester, const DataExportRequestScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Télécharger l\'archive ZIP'));
      await tester.pumpAndSettle();

      verify(() => repo.downloadUrl(completedExport.id)).called(1);
      verify(
        () => downloader.download(
          url: 'https://storage.example.com/e/abc.zip?sig=x',
          suggestedFileName: 'steriymed-export-abcdef12.zip',
        ),
      ).called(1);

      // Success feedback with the "Ouvrir" action is shown.
      expect(find.text('Téléchargement terminé.'), findsOneWidget);
      expect(find.text('Ouvrir'), findsOneWidget);
    },
  );

  testWidgets('a download failure surfaces the French error message',
      (tester) async {
    when(() => repo.list(forceRefresh: any(named: 'forceRefresh')))
        .thenAnswer((_) async => [completedExport]);
    when(() => repo.downloadUrl(completedExport.id))
        .thenAnswer((_) async => 'https://storage.example.com/e/abc.zip');
    when(() => downloader.download(
          url: any(named: 'url'),
          suggestedFileName: any(named: 'suggestedFileName'),
        )).thenThrow(
      // ApiException.from keeps the French message as-is.
      Exception('boom'),
    );

    await pumpApp(tester, const DataExportRequestScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Télécharger l\'archive ZIP'));
    await tester.pumpAndSettle();

    verify(() => repo.downloadUrl(completedExport.id)).called(1);
    // The download button is interactable again (spinner cleared).
    expect(find.text('Télécharger l\'archive ZIP'), findsOneWidget);
  });
}
