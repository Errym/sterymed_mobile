import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/storage/outbox/sync_engine.dart';
import 'package:steriymed_mobile/core/sync/sync_status_cubit.dart';

import '../../mocks/mock_connectivity.dart';
import '../../mocks/mock_outbox_store.dart';

class MockSyncEngine extends Mock implements SyncEngine {}

void main() {
  late MockOutboxStore store;
  late MockSyncEngine engine;
  late MockConnectivityService connectivity;

  setUp(() {
    store = MockOutboxStore();
    engine = MockSyncEngine();
    connectivity = MockConnectivityService();
    when(() => store.manualReview()).thenReturn([]);
    when(() => engine.flush()).thenAnswer((_) async => 0);
    when(() => connectivity.dispose()).thenReturn(null);
  });

  SyncStatusCubit buildCubit() => SyncStatusCubit(
        store: store,
        engine: engine,
        connectivity: connectivity,
      );

  test('does not flush when the app starts offline', () async {
    when(() => connectivity.isConnected).thenAnswer((_) async => false);
    when(() => connectivity.onStatusChange)
        .thenAnswer((_) => const Stream<bool>.empty());
    when(() => store.pendingCount).thenReturn(0);

    final cubit = buildCubit();
    await cubit.start();

    verifyNever(() => engine.flush());
    expect(cubit.state.online, isFalse);

    await cubit.close();
  });

  test(
    'flushes pending items immediately when the app starts online, '
    'before start() returns',
    () async {
      when(() => connectivity.isConnected).thenAnswer((_) async => true);
      when(() => connectivity.onStatusChange)
          .thenAnswer((_) => const Stream<bool>.empty());
      when(() => store.pendingCount).thenReturn(1);

      final cubit = buildCubit();
      await cubit.start();

      // start() is awaited fully by bootstrap() before runApp(), so a flush
      // observed here proves it happened before the UI could render.
      verify(() => engine.flush()).called(1);
      expect(cubit.state.online, isTrue);

      await cubit.close();
    },
  );

  test(
    'still flushes when connectivity transitions from offline to online '
    '(existing reconnect behavior unchanged)',
    () async {
      final controller = StreamController<bool>();
      when(() => connectivity.isConnected).thenAnswer((_) async => false);
      when(() => connectivity.onStatusChange)
          .thenAnswer((_) => controller.stream);
      when(() => store.pendingCount).thenReturn(0);

      final cubit = buildCubit();
      await cubit.start();
      verifyNever(() => engine.flush());

      controller.add(true);
      await untilCalled(() => engine.flush());

      verify(() => engine.flush()).called(1);

      await controller.close();
      await cubit.close();
    },
  );
}
