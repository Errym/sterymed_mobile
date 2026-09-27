// Task 2 (test coverage completion). This stub was named after a
// ProstheticStatusBloc that doesn't exist — status transitions are handled
// directly by _ProstheticCaseDetailScreenState._changeStatus via setState
// + repository calls, no bloc. Per the user's explicit choice ("test the
// real pattern instead"), this tests that real behavior on the detail
// screen: which transitions are offered, the confirmation gate on the two
// critical ones (placed/cancelled — mirrors the backend's own
// ProstheticCaseStatus::allowedNextStatuses(), see the model's doc
// comment), and permission gating.
//
// prosthetic_case_detail_test.dart already covers the Quick Edit sheet
// flow on this same screen — not duplicated here.

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/storage/session_store.dart';
import 'package:steriymed_mobile/features/prosthetic/data/models/prosthetic_case_data.dart';
import 'package:steriymed_mobile/features/prosthetic/data/repositories/prosthetic_repository.dart';
import 'package:steriymed_mobile/features/prosthetic/presentation/screens/prosthetic_case_detail_screen.dart';

import '../helpers/pump_app.dart';

class MockSessionStore extends Mock implements SessionStore {}

class MockProstheticRepository extends Mock implements ProstheticRepository {}

ProstheticCaseData _buildCase({
  ProstheticCaseStatus status = ProstheticCaseStatus.sentToLaboratory,
}) =>
    ProstheticCaseData(
      id: 'case-1',
      patientId: 'p1',
      patientReference: 'PAT-000001',
      practitionerId: 'prat-1',
      practitionerName: 'Dr Test',
      status: status,
      impressionType: ProstheticImpressionType.digital,
      workType: ProstheticWorkType.crown,
      impressionDate: DateTime(2026, 9, 1),
      createdAt: DateTime(2026, 9, 1),
    );

void main() {
  late MockSessionStore session;
  late MockProstheticRepository repo;

  setUp(() {
    session = MockSessionStore();
    repo = MockProstheticRepository();

    when(() => session.hasPermission(any())).thenReturn(true);
    when(() => repo.show(any())).thenAnswer((_) async => _buildCase());
    when(() => repo.statusHistory(any())).thenAnswer((_) async => []);
    when(() => repo.listAttachments(any())).thenAnswer((_) async => []);

    if (GetIt.instance.isRegistered<SessionStore>()) {
      GetIt.instance.unregister<SessionStore>();
    }
    if (GetIt.instance.isRegistered<ProstheticRepository>()) {
      GetIt.instance.unregister<ProstheticRepository>();
    }
    GetIt.instance.registerSingleton<SessionStore>(session);
    GetIt.instance.registerSingleton<ProstheticRepository>(repo);
  });

  tearDown(() {
    GetIt.instance.unregister<SessionStore>();
    GetIt.instance.unregister<ProstheticRepository>();
  });

  testWidgets(
    'offers exactly the backend-mirrored next statuses for '
    'sentToLaboratory, and none for a user without prosthetic_cases.manage',
    (tester) async {
      await pumpApp(
        tester,
        const ProstheticCaseDetailScreen(caseId: 'case-1'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reçu au cabinet'), findsOneWidget);
      expect(find.text('Annulé'), findsOneWidget);

      when(() => session.hasPermission('prosthetic_cases.manage'))
          .thenReturn(false);
      await pumpApp(
        tester,
        const ProstheticCaseDetailScreen(caseId: 'case-1'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Changer le statut'), findsNothing);
    },
  );

  testWidgets(
    'a non-critical transition (receivedAtPractice) calls changeStatus '
    'directly, with no confirmation dialog',
    (tester) async {
      when(() => repo.changeStatus(any(), status: any(named: 'status')))
          .thenAnswer((_) async => _buildCase(
                status: ProstheticCaseStatus.receivedAtPractice,
              ));

      await pumpApp(
        tester,
        const ProstheticCaseDetailScreen(caseId: 'case-1'),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reçu au cabinet'));
      await tester.pumpAndSettle();

      verify(() => repo.changeStatus(
            'case-1',
            status: 'received_at_practice',
          )).called(1);
      expect(find.text('Statut mis à jour.'), findsOneWidget);
    },
  );

  testWidgets(
    'the critical "Annulé" transition shows a confirmation dialog and only '
    'calls changeStatus after confirming',
    (tester) async {
      when(() => repo.changeStatus(any(), status: any(named: 'status')))
          .thenAnswer(
              (_) async => _buildCase(status: ProstheticCaseStatus.cancelled));

      await pumpApp(
        tester,
        const ProstheticCaseDetailScreen(caseId: 'case-1'),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Annulé'));
      await tester.pumpAndSettle();

      expect(find.text('Annuler ce dossier ?'), findsOneWidget);
      verifyNever(() => repo.changeStatus(any(), status: any(named: 'status')));

      await tester.tap(find.text('Confirmer'));
      await tester.pumpAndSettle();

      verify(() => repo.changeStatus('case-1', status: 'cancelled')).called(1);
    },
  );

  testWidgets(
    'cancelling the confirmation dialog for a critical transition does not '
    'call changeStatus',
    (tester) async {
      await pumpApp(
        tester,
        const ProstheticCaseDetailScreen(caseId: 'case-1'),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Annulé'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler').first);
      await tester.pumpAndSettle();

      verifyNever(() => repo.changeStatus(any(), status: any(named: 'status')));
      expect(find.text('Annuler ce dossier ?'), findsNothing);
    },
  );
}
