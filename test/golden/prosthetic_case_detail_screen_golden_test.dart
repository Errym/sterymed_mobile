// Golden 4/4: prosthetic case detail screen. Setup mirrors
// test/widget/prosthetic_case_detail_test.dart (same mock
// repository/session wiring and fixture data) — this file only adds a
// fixed surface size and a matchesGoldenFile assertion on top of that
// already-covered behavior.

@TestOn('windows')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/storage/session_store.dart';
import 'package:steriymed_mobile/features/prosthetic/data/models/prosthetic_case_data.dart';
import 'package:steriymed_mobile/features/prosthetic/data/models/prosthetic_case_status_history_data.dart';
import 'package:steriymed_mobile/features/prosthetic/data/repositories/prosthetic_repository.dart';
import 'package:steriymed_mobile/features/prosthetic/presentation/screens/prosthetic_case_detail_screen.dart';

import '../helpers/pump_app.dart';
import 'golden_helpers.dart';

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

  testWidgets('prosthetic case detail screen matches golden', (tester) async {
    await setGoldenSurfaceSize(tester);

    await pumpApp(
      tester,
      const ProstheticCaseDetailScreen(caseId: 'case-1'),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(ProstheticCaseDetailScreen),
      matchesGoldenFile('goldens/prosthetic_case_detail_screen.png'),
    );
  });
}
