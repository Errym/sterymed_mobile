// Widget test for Task 1.2 (DETAIL SCREEN completion) — covers the one
// real gap found against the brief (page 7, "Quick Edit ... actions"):
// the case detail screen now exposes an edit action backed by the real
// PATCH /v1/prosthetic-cases/{id} endpoint. Print/Export is deliberately
// not covered here — see docs/BACKEND_BUGS.md#bug-024, no such endpoint
// exists on the backend to test against.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/storage/session_store.dart';
import 'package:steriymed_mobile/features/prosthetic/data/models/prosthetic_case_data.dart';
import 'package:steriymed_mobile/features/prosthetic/data/models/prosthetic_case_status_history_data.dart';
import 'package:steriymed_mobile/features/prosthetic/data/repositories/prosthetic_repository.dart';
import 'package:steriymed_mobile/features/prosthetic/presentation/screens/prosthetic_case_detail_screen.dart';

import '../helpers/pump_app.dart';

class MockSessionStore extends Mock implements SessionStore {}

class MockProstheticRepository extends Mock implements ProstheticRepository {}

ProstheticCaseData _buildCase() => ProstheticCaseData(
      id: 'case-1',
      patientId: 'p1',
      patientReference: 'PAT-000001',
      practitionerId: 'prat-1',
      practitionerName: 'Dr Test',
      status: ProstheticCaseStatus.sentToLaboratory,
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
    when(() => repo.statusHistory(any())).thenAnswer(
      (_) async => [
        ProstheticCaseStatusHistoryData(
          id: 'h1',
          toStatus: 'sent_to_laboratory',
          changedByUserId: 'prat-1',
          changedByName: 'Dr Test',
          createdAt: DateTime(2026, 9, 1),
        ),
      ],
    );
    when(() => repo.listAttachments(any())).thenAnswer((_) async => []);
    when(() => repo.listLaboratories()).thenAnswer((_) async => []);
    when(() => repo.update(any(), any()))
        .thenAnswer((_) async => _buildCase());

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
    'shows an edit action for a user with prosthetic_cases.manage',
    (tester) async {
      await pumpApp(
        tester,
        const ProstheticCaseDetailScreen(caseId: 'case-1'),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    },
  );

  testWidgets(
    'hides the edit action for a user without prosthetic_cases.manage',
    (tester) async {
      when(() => session.hasPermission(any())).thenReturn(false);

      await pumpApp(
        tester,
        const ProstheticCaseDetailScreen(caseId: 'case-1'),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.edit_outlined), findsNothing);
    },
  );

  testWidgets(
    'editing and saving calls the real update endpoint and refreshes',
    (tester) async {
      await pumpApp(
        tester,
        const ProstheticCaseDetailScreen(caseId: 'case-1'),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Modifier le dossier'), findsOneWidget);

      await tester.dragUntilVisible(
        find.text('Enregistrer'),
        find.byType(SingleChildScrollView),
        const Offset(0, -200),
      );
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      final captured =
          verify(() => repo.update('case-1', captureAny())).captured.single
              as Map<String, dynamic>;
      expect(captured['impression_type'], 'digital');
      expect(captured['work_type'], 'crown');
      // The server rejects a patch that mixes clinical and payment fields from
      // a caller who holds only one of the two permissions, so the clinical
      // edit must never carry a payment field.
      const paymentFields = [
        'deposit_requested',
        'deposit_received',
        'deposit_amount',
        'final_payment_completed',
        'remaining_balance',
        'administrative_comments',
      ];
      for (final field in paymentFields) {
        expect(captured.containsKey(field), isFalse, reason: field);
      }
      expect(
        captured['impression_date'],
        DateTime(2026, 9, 1).toIso8601String().split('T').first,
      );

      // Sheet closed and the case was reloaded (show() called again).
      expect(find.text('Modifier le dossier'), findsNothing);
      verify(() => repo.show('case-1')).called(2);
      expect(find.text('Dossier mis à jour.'), findsOneWidget);
    },
  );
}
