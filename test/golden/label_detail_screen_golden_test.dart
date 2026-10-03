// Golden 3/4: label detail screen (valid label, loaded state). Setup
// mirrors test/widget/label_detail_screen_test.dart (same mock
// repositories/session wiring and fixture data) — this file only adds a
// fixed surface size and a matchesGoldenFile assertion on top of that
// already-covered behavior.

@TestOn('windows')
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/storage/session_store.dart';
import 'package:steriymed_mobile/features/labels/data/models/label_scan_result.dart';
import 'package:steriymed_mobile/features/labels/data/repositories/label_repository.dart';
import 'package:steriymed_mobile/features/labels/data/repositories/label_usage_repository.dart';
import 'package:steriymed_mobile/features/labels/presentation/screens/label_detail_screen.dart';

import '../helpers/pump_app.dart';
import 'golden_helpers.dart';

class MockLabelRepository extends Mock implements LabelRepository {}

class MockLabelUsageRepository extends Mock implements LabelUsageRepository {}

class MockSessionStore extends Mock implements SessionStore {}

final _result = LabelScanResult(
  labelId: 'label-1',
  status: LabelScanStatus.printed,
  cycleNumber: 12,
  deviceName: 'Autoclave Salle 2',
  sterilizedAt: DateTime(2026, 1, 1),
  useByDate: DateTime(2026, 6, 1),
  sequenceInCycle: 1,
  siteName: 'Cabinet Principal',
);

void main() {
  late MockLabelRepository repo;
  late MockLabelUsageRepository usageRepo;
  late MockSessionStore session;

  setUp(() {
    repo = MockLabelRepository();
    usageRepo = MockLabelUsageRepository();
    session = MockSessionStore();
    when(() => usageRepo.history(any())).thenAnswer((_) async => []);
    when(() => session.hasPermission(any())).thenReturn(true);
    if (GetIt.instance.isRegistered<SessionStore>()) {
      GetIt.instance.unregister<SessionStore>();
    }
    GetIt.instance.registerSingleton<SessionStore>(session);
  });

  tearDown(() {
    if (GetIt.instance.isRegistered<SessionStore>()) {
      GetIt.instance.unregister<SessionStore>();
    }
  });

  Widget wrap(Widget child) => MultiRepositoryProvider(
        providers: [
          RepositoryProvider<LabelRepository>.value(value: repo),
          RepositoryProvider<LabelUsageRepository>.value(value: usageRepo),
        ],
        child: child,
      );

  testWidgets('label detail screen matches golden', (tester) async {
    when(() => repo.getByCode(any())).thenAnswer((_) async => _result);
    await setGoldenSurfaceSize(tester);

    await pumpApp(tester, wrap(const LabelDetailScreen(code: 'LOT-42')));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(LabelDetailScreen),
      matchesGoldenFile('goldens/label_detail_screen.png'),
    );
  });
}
