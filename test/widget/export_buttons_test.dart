// Phase 7 / T7.4 + T4.6: the label evidence dossier (PDF) and the evidence
// search export (CSV) are real saved files, shown only to roles allowed to
// export, with the exact filters of the search on screen.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/config/api_endpoints.dart';
import 'package:steriymed_mobile/core/errors/api_exception.dart';
import 'package:steriymed_mobile/core/files/file_export_service.dart';
import 'package:steriymed_mobile/core/network/cursor_page.dart';
import 'package:steriymed_mobile/core/storage/session_store.dart';
import 'package:steriymed_mobile/features/labels/data/models/label_scan_result.dart';
import 'package:steriymed_mobile/features/labels/data/models/label_usage_data.dart';
import 'package:steriymed_mobile/features/labels/data/repositories/label_repository.dart';
import 'package:steriymed_mobile/features/labels/data/repositories/label_usage_repository.dart';
import 'package:steriymed_mobile/features/labels/presentation/screens/label_detail_screen.dart';
import 'package:steriymed_mobile/features/reporting/data/models/evidence_search_result_data.dart';
import 'package:steriymed_mobile/features/reporting/data/repositories/evidence_search_repository.dart';
import 'package:steriymed_mobile/features/reporting/presentation/screens/evidence_search_screen.dart';

import '../helpers/pump_app.dart';

class _MockSession extends Mock implements SessionStore {}

class _MockFiles extends Mock implements FileExportService {}

class _MockHandoff extends Mock implements FileHandoff {}

class _MockLabels extends Mock implements LabelRepository {}

class _MockUsage extends Mock implements LabelUsageRepository {}

class _MockEvidence extends Mock implements EvidenceSearchRepository {}

void _register<T extends Object>(T v) {
  if (GetIt.instance.isRegistered<T>()) GetIt.instance.unregister<T>();
  GetIt.instance.registerSingleton<T>(v);
}

void main() {
  late _MockSession session;
  late _MockFiles files;
  late _MockHandoff handoff;

  setUpAll(() => registerFallbackValue(File('fallback')));

  setUp(() {
    session = _MockSession();
    files = _MockFiles();
    handoff = _MockHandoff();
    when(() => session.hasPermission(any())).thenReturn(true);
    _register<SessionStore>(session);
    _register<FileExportService>(files);
    _register<FileHandoff>(handoff);
  });

  tearDown(() => GetIt.instance.reset());

  group('label evidence dossier (PDF)', () {
    late _MockLabels labels;
    late _MockUsage usage;

    final scan = LabelScanResult(
      labelId: 'label-1',
      status: LabelScanStatus.used,
      cycleNumber: 12,
      deviceName: 'Autoclave Salle 2',
      sterilizedAt: DateTime(2026, 1, 1),
      useByDate: DateTime(2026, 6, 1),
      sequenceInCycle: 1,
      siteName: 'Cabinet Principal',
      usageRecorded: true,
    );

    final used = LabelUsageData(
      id: 'u1',
      labelId: 'label-1',
      patientId: 'p1',
      patientReference: 'PAT-000001',
      practitionerId: 'pr1',
      procedure: 'Détartrage',
      usedAt: DateTime(2026, 2, 1, 9),
    );

    Future<void> pumpDetail(WidgetTester tester) async {
      await pumpApp(
        tester,
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<LabelRepository>.value(value: labels),
            RepositoryProvider<LabelUsageRepository>.value(value: usage),
          ],
          child: const LabelDetailScreen(code: 'LOT-42'),
        ),
      );
      await tester.pumpAndSettle();
    }

    setUp(() {
      labels = _MockLabels();
      usage = _MockUsage();
      when(() => labels.getByCode(any())).thenAnswer((_) async => scan);
    });

    testWidgets('appears once a use is recorded and saves the real PDF',
        (tester) async {
      when(() => usage.history(any())).thenAnswer((_) async => [used]);
      final saved = File('${Directory.systemTemp.path}/dossier.pdf');
      when(() => files.saveFromApi(
            any(),
            query: any(named: 'query'),
            baseName: any(named: 'baseName'),
            extension: any(named: 'extension'),
          )).thenAnswer((_) async => saved);

      await pumpDetail(tester);
      await tester.scrollUntilVisible(
        find.byKey(const Key('label-export-dossier')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('label-export-dossier')));
      await tester.pumpAndSettle();

      verify(() => files.saveFromApi(
            ApiEndpoints.labelUsageDossier('label-1'),
            query: any(named: 'query'),
            baseName: 'dossier-preuve',
            extension: 'pdf',
          )).called(1);
      expect(find.byKey(const Key('saved-file-open')), findsOneWidget);
    });

    testWidgets('is absent when nothing was ever recorded for the label',
        (tester) async {
      when(() => usage.history(any())).thenAnswer((_) async => []);
      await pumpDetail(tester);
      expect(find.byKey(const Key('label-export-dossier')), findsNothing);
    });

    testWidgets('a refusal is shown in French and nothing is opened',
        (tester) async {
      when(() => usage.history(any())).thenAnswer((_) async => [used]);
      when(() => files.saveFromApi(
            any(),
            query: any(named: 'query'),
            baseName: any(named: 'baseName'),
            extension: any(named: 'extension'),
          )).thenThrow(const ApiException(
        code: 'FORBIDDEN',
        message: 'Votre rôle ne permet pas cet export.',
        statusCode: 403,
      ));
      await pumpDetail(tester);
      await tester.scrollUntilVisible(
        find.byKey(const Key('label-export-dossier')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('label-export-dossier')));
      await tester.pumpAndSettle();
      expect(find.text('Votre rôle ne permet pas cet export.'), findsOneWidget);
      verifyNever(() => handoff.open(any()));
    });
  });

  group('evidence search export (CSV)', () {
    late _MockEvidence evidence;

    final row = EvidenceSearchResultData(
      labelId: 'l1',
      labelStatus: 'used',
      cycleNumber: 7,
      deviceName: 'Autoclave A',
      siteName: 'Cabinet',
      operatorName: 'Op',
      batchNumber: 'LOT-9',
      patientReference: 'PAT-000001',
      practitionerName: 'Dr Test',
      procedure: 'Soin',
      usedAt: DateTime(2026, 9, 1, 10),
    );

    setUp(() {
      evidence = _MockEvidence();
      _register<EvidenceSearchRepository>(evidence);
      when(() => evidence.search(
            cursor: any(named: 'cursor'),
            patientReference: any(named: 'patientReference'),
            cycleNumber: any(named: 'cycleNumber'),
            batchNumber: any(named: 'batchNumber'),
            from: any(named: 'from'),
            to: any(named: 'to'),
          )).thenAnswer((_) async => CursorPage(items: [row]));
    });

    Future<void> searchFor(WidgetTester tester, String patient) async {
      await pumpApp(tester, const EvidenceSearchScreen());
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).first, patient);
      await tester.tap(find.text('Rechercher'));
      await tester.pumpAndSettle();
    }

    testWidgets('exports exactly the filters of the last search',
        (tester) async {
      final saved = File('${Directory.systemTemp.path}/preuves.csv');
      when(() => files.saveFromApi(
            any(),
            query: any(named: 'query'),
            baseName: any(named: 'baseName'),
            extension: any(named: 'extension'),
          )).thenAnswer((_) async => saved);

      await searchFor(tester, 'PAT-000001');
      await tester.tap(find.byKey(const Key('evidence-export-csv')));
      await tester.pumpAndSettle();

      final captured = verify(() => files.saveFromApi(
            ApiEndpoints.evidenceExport,
            query: captureAny(named: 'query'),
            baseName: 'preuves',
            extension: 'csv',
          )).captured.single as Map<String, dynamic>;
      expect(captured['patient_reference'], 'PAT-000001');
      expect(captured['format'], 'csv');
      expect(find.byKey(const Key('saved-file-open')), findsOneWidget);
    });

    testWidgets('is hidden for a role without exports.manage', (tester) async {
      when(() => session.hasPermission(any())).thenReturn(false);
      await searchFor(tester, 'PAT-000001');
      expect(find.text('PAT-000001 · Dr Test'), findsNothing);
      expect(find.byKey(const Key('evidence-export-csv')), findsNothing);
      // The search itself still works for them.
      expect(find.text('N°7'), findsOneWidget);
    });

    testWidgets('is not offered before any search or on an empty result',
        (tester) async {
      when(() => evidence.search(
            cursor: any(named: 'cursor'),
            patientReference: any(named: 'patientReference'),
            cycleNumber: any(named: 'cycleNumber'),
            batchNumber: any(named: 'batchNumber'),
            from: any(named: 'from'),
            to: any(named: 'to'),
          )).thenAnswer((_) async => const CursorPage(items: []));
      await pumpApp(tester, const EvidenceSearchScreen());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('evidence-export-csv')), findsNothing);
      await tester.enterText(find.byType(EditableText).first, 'ZZZ');
      await tester.tap(find.text('Rechercher'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('evidence-export-csv')), findsNothing);
    });

    testWidgets('a failed first search shows the error with retry, not the '
        'invitation to search', (tester) async {
      when(() => evidence.search(
            cursor: any(named: 'cursor'),
            patientReference: any(named: 'patientReference'),
            cycleNumber: any(named: 'cycleNumber'),
            batchNumber: any(named: 'batchNumber'),
            from: any(named: 'from'),
            to: any(named: 'to'),
          )).thenThrow(const ApiException(
        code: 'network_error',
        message: 'Connexion impossible. Vérifiez votre réseau.',
      ));
      await searchFor(tester, 'PAT-000001');
      expect(find.text('Connexion impossible. Vérifiez votre réseau.'),
          findsOneWidget);
      expect(find.text('Lancez une recherche'), findsNothing);
    });
  });
}
