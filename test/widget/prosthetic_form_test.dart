// Widget test operationalizing the brief's acceptance criterion (page 15,
// "Create"): "A user can create a complete prosthetic case in under 2
// minutes." A widget test can't measure wall-clock minutes, so this proves
// the mechanism the brief actually asks for instead (page 6: "Creation
// must be quick: use searchable dropdowns, sensible defaults and prefilled
// dates wherever possible") — that every field except the required patient
// link already carries a valid default, so the *minimum* interaction path
// (pick a patient, tap submit) alone produces a complete, valid
// POST /v1/prosthetic-cases payload with zero additional typing.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/storage/session_store.dart';
import 'package:steriymed_mobile/features/identity/data/models/practitioner_option.dart';
import 'package:steriymed_mobile/features/identity/data/repositories/practitioner_repository.dart';
import 'package:steriymed_mobile/features/patients/data/models/patient_data.dart';
import 'package:steriymed_mobile/features/patients/data/repositories/patient_repository.dart';
import 'package:steriymed_mobile/features/prosthetic/data/local/prosthetic_case_draft_store.dart';
import 'package:steriymed_mobile/features/prosthetic/data/models/prosthetic_case_data.dart';
import 'package:steriymed_mobile/features/prosthetic/data/repositories/prosthetic_repository.dart';
import 'package:steriymed_mobile/features/prosthetic/presentation/screens/prosthetic_case_create_screen.dart';

import '../helpers/pump_app.dart';

class MockSessionStore extends Mock implements SessionStore {}

class MockProstheticCaseDraftStore extends Mock
    implements ProstheticCaseDraftStore {}

class MockProstheticRepository extends Mock implements ProstheticRepository {}

class MockPatientRepository extends Mock implements PatientRepository {}

class MockPractitionerRepository extends Mock
    implements PractitionerRepository {}

const _patient = PatientData(id: 'p1', reference: 'PAT-000001');

const _practitioners = [
  PractitionerOption(id: 'prat-1', name: 'Dr Test', role: 'practitioner'),
  PractitionerOption(id: 'prat-2', name: 'Dr Martin', role: 'admin'),
];

ProstheticCaseData _fakeCase() => ProstheticCaseData(
  id: 'case-1',
  patientId: _patient.id,
  patientReference: _patient.reference,
  practitionerId: 'prat-1',
  practitionerName: 'Dr Test',
  status: ProstheticCaseStatus.impressionCompleted,
  impressionType: ProstheticImpressionType.digital,
  workType: ProstheticWorkType.crown,
  impressionDate: DateTime.now(),
  createdAt: DateTime.now(),
);

void main() {
  late MockSessionStore session;
  late MockProstheticCaseDraftStore draftStore;
  late MockProstheticRepository prostheticRepo;
  late MockPatientRepository patientRepo;
  late MockPractitionerRepository practitionerRepo;

  setUpAll(() {
    registerFallbackValue(const ProstheticCaseDraft());
  });

  setUp(() {
    session = MockSessionStore();
    draftStore = MockProstheticCaseDraftStore();
    prostheticRepo = MockProstheticRepository();
    patientRepo = MockPatientRepository();
    practitionerRepo = MockPractitionerRepository();

    when(() => session.userId).thenReturn('prat-1');
    when(() => session.userName).thenReturn('Dr Test');
    when(() => draftStore.load()).thenReturn(null);
    when(() => draftStore.save(any())).thenAnswer((_) async {});
    when(() => draftStore.clear()).thenAnswer((_) async {});
    when(() => prostheticRepo.listLaboratories()).thenAnswer((_) async => []);
    when(
      () => practitionerRepo.list(forceRefresh: any(named: 'forceRefresh')),
    ).thenAnswer((_) async => _practitioners);
    when(() => patientRepo.search(any())).thenAnswer((_) async => [_patient]);
    when(
      () => prostheticRepo.create(any()),
    ).thenAnswer((_) async => _fakeCase());

    if (GetIt.instance.isRegistered<SessionStore>()) {
      GetIt.instance.unregister<SessionStore>();
    }
    if (GetIt.instance.isRegistered<ProstheticCaseDraftStore>()) {
      GetIt.instance.unregister<ProstheticCaseDraftStore>();
    }
    if (GetIt.instance.isRegistered<ProstheticRepository>()) {
      GetIt.instance.unregister<ProstheticRepository>();
    }
    if (GetIt.instance.isRegistered<PatientRepository>()) {
      GetIt.instance.unregister<PatientRepository>();
    }
    if (GetIt.instance.isRegistered<PractitionerRepository>()) {
      GetIt.instance.unregister<PractitionerRepository>();
    }
    GetIt.instance.registerSingleton<PractitionerRepository>(practitionerRepo);
    GetIt.instance.registerSingleton<SessionStore>(session);
    GetIt.instance.registerSingleton<ProstheticCaseDraftStore>(draftStore);
    GetIt.instance.registerSingleton<ProstheticRepository>(prostheticRepo);
    GetIt.instance.registerSingleton<PatientRepository>(patientRepo);
  });

  tearDown(() {
    GetIt.instance.unregister<SessionStore>();
    GetIt.instance.unregister<ProstheticCaseDraftStore>();
    GetIt.instance.unregister<ProstheticRepository>();
    GetIt.instance.unregister<PatientRepository>();
    GetIt.instance.unregister<PractitionerRepository>();
  });

  /// Pushes the create screen onto a real navigation stack so its own
  /// `Navigator.of(context).pop(true)` on success has somewhere to go.
  Future<void> pumpCreateScreen(WidgetTester tester) async {
    await pumpApp(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ProstheticCaseCreateScreen(),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'every field except patient already shows a usable default on open',
    (tester) async {
      await pumpCreateScreen(tester);

      // Impression type, work type, and impression date are prefilled —
      // the brief's own "sensible defaults and prefilled dates" requirement.
      expect(find.text('Numérique'), findsOneWidget);
      expect(find.text('Couronne'), findsOneWidget);
      // In the date field and in the live preview.
      expect(
        find.text(DateFormat('dd/MM/yyyy').format(DateTime.now())),
        findsNWidgets(2),
      );
    },
  );

  testWidgets(
    'selecting a patient and submitting — with nothing else touched — '
    'creates a complete, valid case (the <2-minute path)',
    (tester) async {
      await pumpCreateScreen(tester);

      // Step 1: open the patient picker and pick the only result.
      await tester.tap(find.text('Sélectionner un patient'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PAT-000001'));
      await tester.pumpAndSettle();

      // Step 2: submit immediately — no other field touched. The button is
      // below the fold in the test surface's default size, so scroll the
      // form's ListView until it's actually mounted before tapping it.
      await tester.dragUntilVisible(
        find.text('Créer le dossier'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.tap(find.text('Créer le dossier'));
      await tester.pumpAndSettle();

      final captured =
          verify(() => prostheticRepo.create(captureAny())).captured.single
              as Map<String, dynamic>;

      expect(captured['patient_id'], 'p1');
      expect(captured['practitioner_id'], 'prat-1');
      expect(captured['impression_type'], 'digital');
      expect(captured['work_type'], 'crown');
      expect(
        captured['impression_date'],
        DateTime.now().toIso8601String().split('T').first,
      );
      // Optional fields left untouched must not be sent at all.
      expect(captured.containsKey('laboratory_id'), isFalse);
      expect(captured.containsKey('priority'), isFalse);
      expect(captured.containsKey('notes'), isFalse);
      expect(captured.containsKey('internal_comments'), isFalse);

      verify(() => draftStore.clear()).called(1);
      expect(find.text('Dossier prothétique créé.'), findsOneWidget);
    },
  );

  Future<void> pickPatientAndScrollToSubmit(WidgetTester tester) async {
    await tester.tap(find.text('Sélectionner un patient'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PAT-000001'));
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.dragUntilVisible(
      find.text('Créer le dossier'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.tap(find.text('Créer le dossier'));
    await tester.pumpAndSettle();
  }

  testWidgets('the practitioner defaults to the signed-in user when eligible', (
    tester,
  ) async {
    await pumpCreateScreen(tester);

    expect(find.text('Dr Test'), findsOneWidget);
  });

  testWidgets('choosing another practitioner sends that person', (
    tester,
  ) async {
    await pumpCreateScreen(tester);
    await pickPatientAndScrollToSubmit(tester);

    // The practitioner's name is also in the preview: target the picker.
    final picker = find.byKey(const Key('prosthetic-practitioner-picker'));
    await tester.dragUntilVisible(
      picker,
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.tap(find.descendant(of: picker, matching: find.text('Dr Test')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dr Martin').last);
    await tester.pumpAndSettle();
    await submit(tester);

    final captured =
        verify(() => prostheticRepo.create(captureAny())).captured.single
            as Map<String, dynamic>;
    expect(captured['practitioner_id'], 'prat-2');
  });

  testWidgets(
    'a signed-in user who is not an eligible practitioner must choose one: '
    'nothing is sent until they do',
    (tester) async {
      when(() => session.userId).thenReturn('someone-else');

      await pumpCreateScreen(tester);
      await pickPatientAndScrollToSubmit(tester);
      await submit(tester);

      expect(find.text('Choisissez un praticien.'), findsOneWidget);
      verifyNever(() => prostheticRepo.create(any()));
    },
  );

  testWidgets(
    'a practitioner saved in a draft who is no longer valid is dropped, not '
    'submitted',
    (tester) async {
      when(() => draftStore.load()).thenReturn(
        const ProstheticCaseDraft(
          patientId: 'p1',
          patientReference: 'PAT-000001',
          practitionerId: 'left-the-practice',
        ),
      );
      when(() => session.userId).thenReturn('someone-else');

      await pumpCreateScreen(tester);
      await submit(tester);

      verifyNever(() => prostheticRepo.create(any()));
      expect(find.text('Choisissez un praticien.'), findsOneWidget);
    },
  );

  testWidgets('a failure to load practitioners is shown with a retry', (
    tester,
  ) async {
    when(
      () => practitionerRepo.list(forceRefresh: any(named: 'forceRefresh')),
    ).thenThrow(Exception('réseau'));

    await pumpCreateScreen(tester);
    await tester.dragUntilVisible(
      find.text('Réessayer'),
      find.byType(ListView),
      const Offset(0, -200),
    );

    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets('the preview follows the form: patient, work type, priority',
      (tester) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpCreateScreen(tester);
    final preview = find.byKey(const Key('prosthetic-preview'));
    expect(
      find.descendant(of: preview, matching: find.text('Choisissez un patient')),
      findsOneWidget,
    );

    await pickPatientAndScrollToSubmit(tester);
    await tester.tap(find.byKey(const Key('prosthetic-priority-Urgente')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: preview, matching: find.text('Urgente')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: preview, matching: find.textContaining('COURONNE')),
      findsOneWidget,
    );
  });

  testWidgets('an urgent case is sent as urgent', (tester) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpCreateScreen(tester);
    await pickPatientAndScrollToSubmit(tester);
    await tester.tap(find.byKey(const Key('prosthetic-priority-Urgente')));
    await tester.pumpAndSettle();
    await submit(tester);

    final captured = verify(() => prostheticRepo.create(captureAny())).captured.single
        as Map<String, dynamic>;
    expect(captured['priority'], 'Urgente');
  });
}
