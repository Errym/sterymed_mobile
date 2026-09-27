import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/errors/api_exception.dart';
import 'package:steriymed_mobile/core/storage/session_store.dart';
import 'package:steriymed_mobile/features/labels/data/models/label_scan_result.dart';
import 'package:steriymed_mobile/features/labels/data/repositories/label_repository.dart';
import 'package:steriymed_mobile/features/labels/data/repositories/label_usage_repository.dart';
import 'package:steriymed_mobile/features/labels/presentation/screens/label_detail_screen.dart';

import '../helpers/pump_app.dart';

class MockLabelRepository extends Mock implements LabelRepository {}

class MockLabelUsageRepository extends Mock implements LabelUsageRepository {}

class MockSessionStore extends Mock implements SessionStore {}

final _result = LabelScanResult(
  labelId: 'label-1',
  status: LabelScanStatus.used,
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

  testWidgets('renders device/cycle info for a valid label', (tester) async {
    when(() => repo.getByCode(any())).thenAnswer((_) async => _result);

    await pumpApp(tester, wrap(const LabelDetailScreen(code: 'LOT-42')));
    await tester.pumpAndSettle();

    expect(find.text('Autoclave Salle 2'), findsOneWidget);
  });

  testWidgets('shows error view when the lookup fails', (tester) async {
    when(() => repo.getByCode(any())).thenThrow(
      const ApiException(code: 'not_found', message: 'Étiquette introuvable.'),
    );

    await pumpApp(tester, wrap(const LabelDetailScreen(code: 'UNKNOWN')));
    await tester.pumpAndSettle();

    expect(find.text('Étiquette introuvable.'), findsOneWidget);
  });

  testWidgets('shows loading state before the result arrives', (tester) async {
    // Never-completing future rather than Future.delayed — a real Timer
    // left pending past the test body trips flutter_test's
    // '!timersPending' invariant. We only need the request to still be
    // in flight when we assert, not to actually resolve.
    final neverCompletes = Completer<LabelScanResult>();
    when(() => repo.getByCode(any()))
        .thenAnswer((_) => neverCompletes.future);

    await pumpApp(tester, wrap(const LabelDetailScreen(code: 'LOT-42')));
    await tester.pump();

    expect(find.text('Chargement de l\'étiquette...'), findsOneWidget);
  });
}
