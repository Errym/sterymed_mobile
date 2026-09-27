// Task 2 (test coverage completion). This stub was named after a
// ProstheticCaseDetailBloc that doesn't exist — the whole screen is a
// plain StatefulWidget doing setState + repository calls directly
// (_ProstheticCaseDetailScreenState._load). Per the user's explicit choice
// ("test the real pattern instead"), this tests that: the loading spinner,
// the error+retry path, and rendering the clinical info card + status
// history timeline — none of which prosthetic_case_detail_test.dart (Quick
// Edit flow) or prosthetic_status_bloc_test.dart (status transitions)
// already cover.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/errors/api_exception.dart';
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
      laboratoryName: 'Labo Dentaire Sud',
      createdAt: DateTime(2026, 9, 1),
    );

void main() {
  late MockSessionStore session;
  late MockProstheticRepository repo;

  setUp(() {
    session = MockSessionStore();
    repo = MockProstheticRepository();

    when(() => session.hasPermission(any())).thenReturn(true);
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

  testWidgets('shows a loading spinner before the case arrives',
      (tester) async {
    // Never-completing future rather than Future.delayed — a real Timer
    // left pending past the test body trips flutter_test's
    // '!timersPending' invariant (see label_detail_screen_test.dart for
    // the same pattern).
    final neverCompletes = Completer<ProstheticCaseData>();
    when(() => repo.show(any())).thenAnswer((_) => neverCompletes.future);
    when(() => repo.statusHistory(any())).thenAnswer((_) async => []);

    await pumpApp(
      tester,
      const ProstheticCaseDetailScreen(caseId: 'case-1'),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows the real error message and retries on demand',
      (tester) async {
    when(() => repo.show(any())).thenThrow(
      const ApiException(code: 'not_found', message: 'Dossier introuvable.'),
    );
    when(() => repo.statusHistory(any())).thenAnswer((_) async => []);

    await pumpApp(
      tester,
      const ProstheticCaseDetailScreen(caseId: 'case-1'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dossier introuvable.'), findsOneWidget);

    when(() => repo.show(any())).thenAnswer((_) async => _buildCase());
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();

    expect(find.text('PAT-000001'), findsOneWidget);
    verify(() => repo.show('case-1')).called(2);
  });

  testWidgets(
    'renders the clinical info card and the status history timeline',
    (tester) async {
      when(() => repo.show(any())).thenAnswer((_) async => _buildCase());
      when(() => repo.statusHistory(any())).thenAnswer(
        (_) async => [
          ProstheticCaseStatusHistoryData(
            id: 'h1',
            toStatus: 'sent_to_laboratory',
            changedByUserId: 'prat-1',
            changedByName: 'Dr Test',
            note: 'Envoi standard',
            createdAt: DateTime(2026, 9, 2, 10, 0),
          ),
        ],
      );

      await pumpApp(
        tester,
        const ProstheticCaseDetailScreen(caseId: 'case-1'),
      );
      await tester.pumpAndSettle();

      // Clinical info card.
      expect(find.text('Dr Test'), findsOneWidget);
      expect(find.text('Numérique'), findsOneWidget);
      expect(find.text('Couronne'), findsOneWidget);
      expect(find.text('Labo Dentaire Sud'), findsOneWidget);

      // Status history is the last section — scroll to it.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -1000));
      await tester.pumpAndSettle();

      // Status history timeline. The top status badge (TypeBadge) upper-cases
      // its own label ("ENVOYÉ AU LABORATOIRE"), so only the history tile
      // itself renders the plain-case label.
      expect(find.text('Envoyé au laboratoire'), findsOneWidget);
      expect(find.textContaining('Dr Test'), findsWidgets);
      expect(find.text('Envoi standard'), findsOneWidget);
    },
  );
}
