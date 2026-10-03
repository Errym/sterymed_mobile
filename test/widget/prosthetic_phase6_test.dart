// Phase 6 acceptance tests (Brief §5, §8, §15): payment block, critical status
// confirmation with the non-blocking payment warning, the seven dashboard
// cards each opening their own server scope, and roles.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/network/cursor_page.dart';
import 'package:steriymed_mobile/core/storage/session_store.dart';
import 'package:steriymed_mobile/features/prosthetic/data/models/prosthetic_case_data.dart';
import 'package:steriymed_mobile/features/prosthetic/data/models/prosthetic_dashboard_data.dart';
import 'package:steriymed_mobile/features/prosthetic/data/models/prosthetic_summary_data.dart';
import 'package:steriymed_mobile/features/prosthetic/data/repositories/prosthetic_repository.dart';
import 'package:steriymed_mobile/features/prosthetic/presentation/screens/prosthetic_case_detail_screen.dart';
import 'package:steriymed_mobile/features/prosthetic/presentation/screens/prosthetic_home_screen.dart';
import 'package:steriymed_mobile/features/prosthetic/presentation/utils/prosthetic_scopes.dart';
import 'package:steriymed_mobile/features/prosthetic/presentation/widgets/prosthetic_payment_section.dart';
import 'package:steriymed_mobile/features/prosthetic/presentation/widgets/prosthetic_status_change_dialog.dart';
import 'package:steriymed_mobile/features/identity/data/repositories/practitioner_repository.dart';

import '../fixtures/prosthetic_case_fixture.dart';
import '../helpers/pump_app.dart';

class _MockSession extends Mock implements SessionStore {}

class _MockRepo extends Mock implements ProstheticRepository {}

class _MockPractitioners extends Mock implements PractitionerRepository {}

void _register<T extends Object>(T instance) {
  if (GetIt.instance.isRegistered<T>()) GetIt.instance.unregister<T>();
  GetIt.instance.registerSingleton<T>(instance);
}

void main() {
  late _MockSession session;
  late _MockRepo repo;

  setUp(() {
    session = _MockSession();
    repo = _MockRepo();
    when(() => session.hasPermission(any())).thenReturn(true);
    _register<SessionStore>(session);
    _register<ProstheticRepository>(repo);
  });

  tearDown(() async {
    await GetIt.instance.reset();
  });

  group('payment block', () {
    Future<List<Map<String, dynamic>>> pumpSection(
      WidgetTester tester, {
      bool canEdit = true,
    }) async {
      final saved = <Map<String, dynamic>>[];
      await pumpApp(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: ProstheticPaymentSection(
              data: buildProstheticCase(),
              canEdit: canEdit,
              busy: false,
              onSave: saved.add,
            ),
          ),
        ),
      );
      return saved;
    }

    testWidgets('"12,50" is saved as 12.5, never as a null', (tester) async {
      final saved = await pumpSection(tester);
      await tester.enterText(
          find.byType(EditableText).at(1), '12,50');
      await tester.ensureVisible(find.text('Enregistrer le paiement'));
      await tester.tap(find.text('Enregistrer le paiement'));
      await tester.pump();
      expect(saved, hasLength(1));
      expect(saved.single['deposit_amount'], 12.5);
    });

    testWidgets('"abc" blocks the save and says why', (tester) async {
      final saved = await pumpSection(tester);
      await tester.enterText(
          find.byType(EditableText).at(1), 'abc');
      await tester.ensureVisible(find.text('Enregistrer le paiement'));
      await tester.tap(find.text('Enregistrer le paiement'));
      await tester.pump();
      expect(saved, isEmpty);
      expect(find.text('Montant invalide (ex. 120,50).'), findsOneWidget);
    });

    testWidgets('a negative amount is refused', (tester) async {
      final saved = await pumpSection(tester);
      await tester.enterText(
          find.byType(EditableText).at(0), '-5');
      await tester.ensureVisible(find.text('Enregistrer le paiement'));
      await tester.tap(find.text('Enregistrer le paiement'));
      await tester.pump();
      expect(saved, isEmpty);
    });

    testWidgets('the balance follows total and received deposit live',
        (tester) async {
      await pumpSection(tester);
      await tester.enterText(
          find.byType(EditableText).at(0), '1200,50');
      await tester.enterText(
          find.byType(EditableText).at(1), '300,25');
      await tester.tap(find.text('Acompte reçu'));
      await tester.pump();
      expect(find.text('900.25'), findsOneWidget);
    });

    testWidgets('a clinician without payment rights sees it read-only',
        (tester) async {
      await pumpSection(tester, canEdit: false);
      expect(find.text('Enregistrer le paiement'), findsNothing);
      expect(find.byType(TextField), findsNothing);
    });
  });

  group('status change dialog', () {
    Future<void> open(
      WidgetTester tester,
      ProstheticCaseData current,
      ProstheticCaseStatus target,
      ValueSetter<ProstheticStatusChange?> onResult,
    ) async {
      await pumpApp(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => onResult(
                await ProstheticStatusChangeDialog.show(
                  context,
                  current: current,
                  target: target,
                ),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
    }

    testWidgets('placing with a balance warns but still lets the user confirm',
        (tester) async {
      ProstheticStatusChange? result;
      var answered = false;
      await open(
        tester,
        buildProstheticCase(
          status: ProstheticCaseStatus.placementScheduled,
          remainingBalance: 80,
        ),
        ProstheticCaseStatus.placed,
        (r) {
          result = r;
          answered = true;
        },
      );
      expect(find.byKey(const Key('status-payment-warning')), findsOneWidget);
      expect(find.text('Confirmer la pose ?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('status-confirm')));
      await tester.pumpAndSettle();
      expect(answered, isTrue);
      expect(result, isNotNull);
    });

    testWidgets('no warning when nothing is owed', (tester) async {
      await open(
        tester,
        buildProstheticCase(status: ProstheticCaseStatus.placementScheduled),
        ProstheticCaseStatus.placed,
        (_) {},
      );
      expect(find.byKey(const Key('status-payment-warning')), findsNothing);
    });

    testWidgets('cancelling asks for confirmation and carries the note',
        (tester) async {
      ProstheticStatusChange? result;
      await open(
        tester,
        buildProstheticCase(status: ProstheticCaseStatus.sentToLaboratory),
        ProstheticCaseStatus.cancelled,
        (r) => result = r,
      );
      expect(find.text('Annuler ce dossier ?'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Patient parti');
      await tester.tap(find.byKey(const Key('status-confirm')));
      await tester.pumpAndSettle();
      expect(result?.note, 'Patient parti');
    });

    testWidgets('going back changes nothing', (tester) async {
      var answered = false;
      ProstheticStatusChange? result;
      await open(
        tester,
        buildProstheticCase(status: ProstheticCaseStatus.sentToLaboratory),
        ProstheticCaseStatus.receivedAtPractice,
        (r) {
          answered = true;
          result = r;
        },
      );
      await tester.tap(find.text('Retour'));
      await tester.pumpAndSettle();
      expect(answered, isTrue);
      expect(result, isNull);
    });
  });

  group('dashboard: no dead KPI', () {
    const dash = ProstheticDashboardData(
      activeCases: 11,
      atLaboratory: 2,
      returnedToPractice: 3,
      waitingForPlacement: 4,
      placementsToday: 5,
      placementsThisWeek: 6,
      depositsOrBalancesDue: 7,
    );

    setUp(() {
      when(() => repo.dashboard(forceRefresh: any(named: 'forceRefresh')))
          .thenAnswer((_) async => dash);
      when(() => repo.listLaboratories())
          .thenAnswer((_) async => const []);
      when(() => repo.list(
            patientReference: any(named: 'patientReference'),
            practitionerId: any(named: 'practitionerId'),
            laboratoryId: any(named: 'laboratoryId'),
            workType: any(named: 'workType'),
            status: any(named: 'status'),
            from: any(named: 'from'),
            to: any(named: 'to'),
            scope: any(named: 'scope'),
            cursor: any(named: 'cursor'),
          )).thenAnswer((_) async => const CursorPage(items: [], nextCursor: null));
      when(() => repo.summary(
            patientReference: any(named: 'patientReference'),
            practitionerId: any(named: 'practitionerId'),
            laboratoryId: any(named: 'laboratoryId'),
            workType: any(named: 'workType'),
            status: any(named: 'status'),
            from: any(named: 'from'),
            to: any(named: 'to'),
            scope: any(named: 'scope'),
          )).thenAnswer((_) async => const ProstheticSummaryData(total: 0));
      final practitioners = _MockPractitioners();
      when(practitioners.list).thenAnswer((_) async => const []);
      _register<PractitionerRepository>(practitioners);
    });

    testWidgets('says what to do first and lists the longest-waiting cases',
        (tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      when(() => repo.waitingForPlacement(
            cursor: any(named: 'cursor'),
            aging: any(named: 'aging'),
          )).thenAnswer((_) async => CursorPage(items: [
            buildProstheticCase(
                id: 'a', patientReference: 'PAT-000011', daysWaitingForPlacement: 3),
            buildProstheticCase(
                id: 'b', patientReference: 'PAT-000022', daysWaitingForPlacement: 21),
          ]));
      await pumpApp(tester, const ProstheticHomeScreen());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('prosthetic-priority')), findsOneWidget);
      expect(find.text('À TRAITER EN PRIORITÉ'), findsOneWidget);
      final list = find.byKey(const Key('longest-waiting'));
      expect(list, findsOneWidget);
      // Oldest first.
      final first = tester.getTopLeft(find.textContaining('PAT-000022')).dy;
      final second = tester.getTopLeft(find.textContaining('PAT-000011')).dy;
      expect(first, lessThan(second));
    });

    testWidgets('a failing waiting list hides only its own block',
        (tester) async {
      when(() => repo.waitingForPlacement(
            cursor: any(named: 'cursor'),
            aging: any(named: 'aging'),
          )).thenThrow(Exception('offline'));
      await pumpApp(tester, const ProstheticHomeScreen());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('longest-waiting')), findsNothing);
      expect(find.text('Travaux actifs'), findsOneWidget);
    });

    const cards = <String, String>{
      'Travaux actifs': ProstheticScope.active,
      'Chez le laboratoire': ProstheticScope.atLaboratory,
      'Revenus au cabinet': ProstheticScope.returnedToPractice,
      'Poses aujourd\'hui': ProstheticScope.placementsToday,
      'Paiements à vérifier': ProstheticScope.paymentsDue,
      'Poses cette semaine': ProstheticScope.placementsThisWeek,
    };

    for (final entry in cards.entries) {
      testWidgets('"${entry.key}" opens the list scoped to ${entry.value}',
          (tester) async {
        tester.view.physicalSize = const Size(900, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await pumpApp(tester, const ProstheticHomeScreen());
        await tester.pumpAndSettle();
        await tester.tap(find.text(entry.key));
        await tester.pumpAndSettle();
        verify(() => repo.list(
              patientReference: any(named: 'patientReference'),
              practitionerId: any(named: 'practitionerId'),
              laboratoryId: any(named: 'laboratoryId'),
              workType: any(named: 'workType'),
              status: any(named: 'status'),
              from: any(named: 'from'),
              to: any(named: 'to'),
              scope: entry.value,
              cursor: any(named: 'cursor'),
            )).called(1);
      });
    }

    testWidgets('every card shows the server number', (tester) async {
      await pumpApp(tester, const ProstheticHomeScreen());
      await tester.pumpAndSettle();
      for (final n in ['11', '2', '3', '4', '5', '6', '7']) {
        expect(find.text(n), findsOneWidget, reason: 'card $n');
      }
    });

    testWidgets('a failed dashboard is an error with retry, not zeros',
        (tester) async {
      when(() => repo.dashboard(forceRefresh: any(named: 'forceRefresh')))
          .thenAnswer((_) async => throw Exception('boom'));
      await pumpApp(tester, const ProstheticHomeScreen());
      await tester.pumpAndSettle();
      expect(find.text('0'), findsNothing);
      expect(find.text('Réessayer'), findsOneWidget);
    });
  });

  group('roles', () {
    setUp(() {
      when(() => repo.show(any())).thenAnswer((_) async => buildProstheticCase(
            status: ProstheticCaseStatus.sentToLaboratory,
            depositRequested: true,
          ));
      when(() => repo.statusHistory(any())).thenAnswer((_) async => []);
      when(() => repo.listAttachments(any())).thenAnswer((_) async => []);
    });

    testWidgets('practitioner: clinical actions yes, payment fields no',
        (tester) async {
      when(() => session.hasPermission(any())).thenReturn(false);
      when(() => session.hasPermission('prosthetic_cases.manage'))
          .thenReturn(true);
      await pumpApp(
          tester, const ProstheticCaseDetailScreen(caseId: 'case-1'));
      await tester.pumpAndSettle();
      expect(find.text('CHANGER LE STATUT'), findsOneWidget);
      expect(find.text('Enregistrer le paiement'), findsNothing);
      expect(find.text('Paiement à vérifier'), findsOneWidget);
    });

    testWidgets('viewer: no status buttons, no edit, no photo, no payment edit',
        (tester) async {
      when(() => session.hasPermission(any())).thenReturn(false);
      await pumpApp(
          tester, const ProstheticCaseDetailScreen(caseId: 'case-1'));
      await tester.pumpAndSettle();
      expect(find.text('CHANGER LE STATUT'), findsNothing);
      expect(find.byTooltip('Modifier'), findsNothing);
      expect(find.byKey(const Key('prosthetic-add-attachment')), findsNothing);
      expect(find.text('Enregistrer le paiement'), findsNothing);
      // ...but they can still read the case and the payment status.
      expect(find.text('PAT-000001'), findsOneWidget);
      expect(find.text('Paiement à vérifier'), findsOneWidget);
    });

    testWidgets('admin: payment block is editable', (tester) async {
      await pumpApp(
          tester, const ProstheticCaseDetailScreen(caseId: 'case-1'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Enregistrer le paiement'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Enregistrer le paiement'), findsOneWidget);
    });
  });
}
