// Task 2 (test coverage completion). This stub was named after a
// LabelUsageBloc that doesn't exist — the screen is a plain StatefulWidget
// doing setState + a getIt-resolved LabelUsageDraftStore/SessionStore and
// a context.read<LabelUsageRepository>() (provider-based) call. Per the
// user's explicit choice ("test the real pattern instead"), this tests
// that real behavior: draft restore, validation, the patient-picker
// happy path, and the real recordUsage payload.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/storage/session_store.dart';
import 'package:steriymed_mobile/features/labels/data/local/label_usage_draft_store.dart';
import 'package:steriymed_mobile/features/labels/data/models/label_usage_data.dart';
import 'package:steriymed_mobile/features/labels/data/repositories/label_usage_repository.dart';
import 'package:steriymed_mobile/features/labels/presentation/screens/label_usage_form_screen.dart';
import 'package:steriymed_mobile/features/patients/data/models/patient_data.dart';
import 'package:steriymed_mobile/features/patients/data/repositories/patient_repository.dart';
import 'package:steriymed_mobile/shared/widgets/inputs/app_search_field.dart';

import '../helpers/pump_app.dart';

class MockDraftStore extends Mock implements LabelUsageDraftStore {}

class MockLabelUsageRepository extends Mock implements LabelUsageRepository {}

class MockPatientRepository extends Mock implements PatientRepository {}

class MockSessionStore extends Mock implements SessionStore {}

void main() {
  late MockDraftStore drafts;
  late MockLabelUsageRepository usageRepo;
  late MockPatientRepository patientRepo;
  late MockSessionStore session;

  setUpAll(() {
    registerFallbackValue(const LabelUsageDraft());
  });

  setUp(() {
    drafts = MockDraftStore();
    patientRepo = MockPatientRepository();
    usageRepo = MockLabelUsageRepository();
    session = MockSessionStore();

    when(() => drafts.load(any())).thenReturn(null);
    when(() => drafts.save(any(), any())).thenAnswer((_) async {});
    when(() => drafts.clear(any())).thenAnswer((_) async {});
    when(() => session.userId).thenReturn('prat-1');
    when(() => session.userName).thenReturn('Dr Test');

    if (GetIt.instance.isRegistered<LabelUsageDraftStore>()) {
      GetIt.instance.unregister<LabelUsageDraftStore>();
    }
    if (GetIt.instance.isRegistered<PatientRepository>()) {
      GetIt.instance.unregister<PatientRepository>();
    }
    if (GetIt.instance.isRegistered<SessionStore>()) {
      GetIt.instance.unregister<SessionStore>();
    }
    GetIt.instance.registerSingleton<LabelUsageDraftStore>(drafts);
    GetIt.instance.registerSingleton<PatientRepository>(patientRepo);
    GetIt.instance.registerSingleton<SessionStore>(session);
  });

  tearDown(() {
    GetIt.instance.unregister<LabelUsageDraftStore>();
    GetIt.instance.unregister<PatientRepository>();
    GetIt.instance.unregister<SessionStore>();
  });

  Widget wrap(Widget child) => RepositoryProvider<LabelUsageRepository>.value(
        value: usageRepo,
        child: child,
      );

  testWidgets('restores a saved draft and shows the restore banner',
      (tester) async {
    when(() => drafts.load('label-1')).thenReturn(
      const LabelUsageDraft(
        patientId: 'p1',
        patientReference: 'PAT-000001',
        procedure: 'Détartrage',
        notes: 'RAS',
      ),
    );

    await pumpApp(
      tester,
      wrap(const LabelUsageFormScreen(labelId: 'label-1')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Brouillon restauré depuis votre dernière saisie.'),
      findsOneWidget,
    );
    expect(find.text('PAT-000001'), findsOneWidget);
    expect(find.text('Détartrage'), findsOneWidget);
  });

  testWidgets('submitting without a patient shows a warning, not a call',
      (tester) async {
    await pumpApp(
      tester,
      wrap(const LabelUsageFormScreen(labelId: 'label-1')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(find.text('Sélectionnez un patient.'), findsOneWidget);
    verifyNever(() => usageRepo.recordUsage(
          labelId: any(named: 'labelId'),
          patientId: any(named: 'patientId'),
          patientReference: any(named: 'patientReference'),
          practitionerId: any(named: 'practitionerId'),
          practitionerName: any(named: 'practitionerName'),
          procedure: any(named: 'procedure'),
          notes: any(named: 'notes'),
        ));
  });

  testWidgets(
    'picking a patient, filling the procedure, and submitting calls '
    'recordUsage with the real session and form values',
    (tester) async {
      when(() => patientRepo.search(any())).thenAnswer(
        (_) async => [const PatientData(id: 'p1', reference: 'PAT-000001')],
      );
      when(() => usageRepo.recordUsage(
            labelId: any(named: 'labelId'),
            patientId: any(named: 'patientId'),
            patientReference: any(named: 'patientReference'),
            practitionerId: any(named: 'practitionerId'),
            practitionerName: any(named: 'practitionerName'),
            procedure: any(named: 'procedure'),
            notes: any(named: 'notes'),
          )).thenAnswer((_) async => LabelUsageData(
            id: 'usage-1',
            labelId: 'label-1',
            patientId: 'p1',
            patientReference: 'PAT-000001',
            practitionerId: 'prat-1',
            procedure: 'Détartrage',
            usedAt: DateTime(2026, 9, 20),
          ));

      await pumpApp(
        tester,
        wrap(const LabelUsageFormScreen(labelId: 'label-1')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sélectionner un patient').first);
      await tester.pumpAndSettle();

      final searchField = find.descendant(
        of: find.byType(AppSearchField),
        matching: find.byType(TextField),
      );
      await tester.enterText(searchField, 'PAT');
      await tester.pump(const Duration(milliseconds: 350)); // debounce
      await tester.pumpAndSettle();

      await tester.tap(find.text('PAT-000001'));
      await tester.pumpAndSettle();

      final procedureField = find.descendant(
        of: find.ancestor(
          of: find.text('Procédure'),
          matching: find.byType(Column),
        ).first,
        matching: find.byType(TextFormField),
      );
      await tester.enterText(procedureField, 'Détartrage');
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      verify(() => usageRepo.recordUsage(
            labelId: 'label-1',
            patientId: 'p1',
            patientReference: 'PAT-000001',
            practitionerId: 'prat-1',
            practitionerName: 'Dr Test',
            procedure: 'Détartrage',
            notes: null,
          )).called(1);
      verify(() => drafts.clear('label-1')).called(1);
      // Not asserting the success snackbar here: _submit() calls
      // Navigator.of(context).pop(true) right after showing it, and with
      // no real back-stack in this bare-MaterialApp test harness (only one
      // route ever exists), popping the sole route tears down its subtree
      // before the snackbar can be observed. The repository/draft-store
      // calls above are the real behavior under test.
    },
  );
}
