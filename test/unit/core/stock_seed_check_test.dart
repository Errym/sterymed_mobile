// Task 3.1, part (b) — the "first-run seed-check helper in bootstrap"
// mitigation for BUG-002/BUG-003 (no dedicated GET /locations or
// GET /batches endpoint). See lib/core/bootstrap/stock_seed_check.dart
// for the full rationale.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/bootstrap/stock_seed_check.dart';
import 'package:steriymed_mobile/core/crash/crash_reporter.dart';
import 'package:steriymed_mobile/core/storage/session_store.dart';
import 'package:steriymed_mobile/features/stock/data/models/stock_option.dart';
import 'package:steriymed_mobile/features/stock/data/repositories/stock_repository.dart';

class MockSessionStore extends Mock implements SessionStore {}

class MockStockRepository extends Mock implements StockRepository {}

class MockCrashReporter extends Mock implements CrashReporter {}

void main() {
  late MockSessionStore session;
  late MockStockRepository stockRepository;
  late MockCrashReporter crashReporter;

  setUp(() {
    session = MockSessionStore();
    stockRepository = MockStockRepository();
    crashReporter = MockCrashReporter();
  });

  test('does nothing when there is no session yet (pre-login bootstrap)',
      () async {
    when(() => session.hasSession).thenReturn(false);

    await checkStockSeedStatus(
      session: session,
      stockRepository: stockRepository,
      crashReporter: crashReporter,
    );

    verifyNever(() => stockRepository.listOptions());
    verifyNever(() => crashReporter.breadcrumb(any(), data: any(named: 'data')));
  });

  test('leaves a breadcrumb when the tenant has zero batches and locations',
      () async {
    when(() => session.hasSession).thenReturn(true);
    when(() => session.tenant).thenReturn({'id': 'tenant-1'});
    when(() => stockRepository.listOptions()).thenAnswer(
      (_) async => (batches: <StockOption>[], locations: <StockOption>[]),
    );

    await checkStockSeedStatus(
      session: session,
      stockRepository: stockRepository,
      crashReporter: crashReporter,
    );

    verify(() => crashReporter.breadcrumb(
          any(that: contains('no batches or locations')),
          data: {'tenantId': 'tenant-1'},
        )).called(1);
  });

  test('does not leave a breadcrumb when stock has been seeded', () async {
    when(() => session.hasSession).thenReturn(true);
    when(() => session.tenant).thenReturn({'id': 'tenant-1'});
    when(() => stockRepository.listOptions()).thenAnswer(
      (_) async => (
        batches: [const StockOption(id: 'b1', label: 'Lot 1')],
        locations: [const StockOption(id: 'l1', label: 'Salle 1')],
      ),
    );

    await checkStockSeedStatus(
      session: session,
      stockRepository: stockRepository,
      crashReporter: crashReporter,
    );

    verifyNever(() => crashReporter.breadcrumb(any(), data: any(named: 'data')));
  });

  test('swallows errors instead of failing bootstrap', () async {
    when(() => session.hasSession).thenReturn(true);
    when(() => session.tenant).thenReturn({'id': 'tenant-1'});
    when(() => stockRepository.listOptions())
        .thenThrow(Exception('network down'));

    await expectLater(
      checkStockSeedStatus(
        session: session,
        stockRepository: stockRepository,
        crashReporter: crashReporter,
      ),
      completes,
    );

    verifyNever(() => crashReporter.breadcrumb(any(), data: any(named: 'data')));
  });
}
