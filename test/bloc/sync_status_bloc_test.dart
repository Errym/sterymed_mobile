// Named sync_status_bloc_test.dart, but the real class is a Cubit —
// lib/core/sync/sync_status_cubit.dart. Tested as such below.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/storage/outbox/outbox_item.dart';
import 'package:steriymed_mobile/core/storage/outbox/outbox_operation.dart';
import 'package:steriymed_mobile/core/storage/outbox/outbox_status.dart';
import 'package:steriymed_mobile/core/storage/outbox/outbox_store.dart';
import 'package:steriymed_mobile/core/storage/outbox/sync_engine.dart';
import 'package:steriymed_mobile/core/sync/connectivity_service.dart';
import 'package:steriymed_mobile/core/sync/sync_status.dart';
import 'package:steriymed_mobile/core/sync/sync_status_cubit.dart';

class MockOutboxStore extends Mock implements OutboxStore {}

class MockSyncEngine extends Mock implements SyncEngine {}

class MockConnectivityService extends Mock implements ConnectivityService {}

void main() {
  late MockOutboxStore store;
  late MockSyncEngine engine;
  late MockConnectivityService connectivity;
  late StreamController<bool> statusChanges;

  setUp(() {
    store = MockOutboxStore();
    engine = MockSyncEngine();
    connectivity = MockConnectivityService();
    statusChanges = StreamController<bool>.broadcast();

    when(() => store.pendingCount).thenReturn(0);
    when(() => store.manualReview()).thenReturn(<OutboxItem>[]);
    when(() => connectivity.onStatusChange)
        .thenAnswer((_) => statusChanges.stream);
    when(() => connectivity.dispose()).thenAnswer((_) async {});
    when(() => engine.flush()).thenAnswer((_) async => 0);
    when(() => engine.isFlushing).thenReturn(false);
  });

  tearDown(() {
    statusChanges.close();
  });

  SyncStatusCubit build() => SyncStatusCubit(
        store: store,
        engine: engine,
        connectivity: connectivity,
      );

  group('SyncStatusCubit', () {
    blocTest<SyncStatusCubit, SyncStatus>(
      'start() while online flushes the outbox and reflects real counts',
      setUp: () {
        when(() => connectivity.isConnected).thenAnswer((_) async => true);
        when(() => store.pendingCount).thenReturn(2);
      },
      build: build,
      act: (c) => c.start(),
      expect: () => [
        isA<SyncStatus>()
            .having((s) => s.online, 'online', true)
            .having((s) => s.pendingCount, 'pendingCount', 2),
        // Emitted right as the flush starts (isSyncing reflects the engine).
        isA<SyncStatus>()
            .having((s) => s.online, 'online', true)
            .having((s) => s.pendingCount, 'pendingCount', 2),
        // Emitted again once the flush completes.
        isA<SyncStatus>()
            .having((s) => s.online, 'online', true)
            .having((s) => s.pendingCount, 'pendingCount', 2),
      ],
      verify: (_) {
        verify(() => engine.flush()).called(1);
      },
    );

    blocTest<SyncStatusCubit, SyncStatus>(
      'reflects isSyncing from the engine and never starts a second flush',
      setUp: () {
        when(() => connectivity.isConnected).thenAnswer((_) async => true);
        when(() => store.pendingCount).thenReturn(1);
        when(() => engine.isFlushing).thenReturn(true);
      },
      build: build,
      act: (c) => c.start(),
      expect: () => [
        isA<SyncStatus>().having((s) => s.isSyncing, 'isSyncing', true),
      ],
      verify: (_) {
        verifyNever(() => engine.flush());
      },
    );

    blocTest<SyncStatusCubit, SyncStatus>(
      'start() while offline never flushes',
      setUp: () {
        when(() => connectivity.isConnected).thenAnswer((_) async => false);
        when(() => store.pendingCount).thenReturn(3);
      },
      build: build,
      act: (c) => c.start(),
      expect: () => [
        isA<SyncStatus>()
            .having((s) => s.online, 'online', false)
            .having((s) => s.pendingCount, 'pendingCount', 3),
      ],
      verify: (_) {
        verifyNever(() => engine.flush());
      },
    );

    test('reconnecting mid-session re-verifies connectivity, then flushes',
        () async {
      when(() => connectivity.isConnected).thenAnswer((_) async => false);
      final cubit = build();
      await cubit.start();
      verifyNever(() => engine.flush());
      expect(cubit.state.online, isFalse);

      // The cubit trusts the real connectivity check, not the event alone.
      when(() => connectivity.isConnected).thenAnswer((_) async => true);
      statusChanges.add(true);
      await untilCalled(() => engine.flush());
      await Future<void>.delayed(Duration.zero);

      verify(() => engine.flush()).called(1);
      expect(cubit.state.online, isTrue);
      await cubit.close();
    });

    test('a connectivity event is ignored when the real check says offline',
        () async {
      when(() => connectivity.isConnected).thenAnswer((_) async => false);
      final cubit = build();
      await cubit.start();

      statusChanges.add(true);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      verifyNever(() => engine.flush());
      expect(cubit.state.online, isFalse);
      await cubit.close();
    });

    test('going offline mid-session updates state without another flush',
        () async {
      when(() => connectivity.isConnected).thenAnswer((_) async => true);
      final cubit = build();
      await cubit.start();
      verify(() => engine.flush()).called(1);

      when(() => connectivity.isConnected).thenAnswer((_) async => false);
      statusChanges.add(false);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(cubit.state.online, isFalse);
      verifyNever(() => engine.flush());
      await cubit.close();
    });

    blocTest<SyncStatusCubit, SyncStatus>(
      'refreshNow() re-reads the outbox without touching connectivity',
      setUp: () {
        when(() => store.pendingCount).thenReturn(5);
        when(() => store.manualReview())
            .thenReturn([_manualReviewItem(), _manualReviewItem()]);
      },
      build: build,
      act: (c) => c.refreshNow(),
      expect: () => [
        isA<SyncStatus>()
            .having((s) => s.pendingCount, 'pendingCount', 5)
            .having((s) => s.manualReviewCount, 'manualReviewCount', 2),
      ],
      verify: (_) {
        verifyNever(() => connectivity.isConnected);
      },
    );

    test('close() cancels the subscription and disposes connectivity',
        () async {
      when(() => connectivity.isConnected).thenAnswer((_) async => true);
      final cubit = build();
      await cubit.start();
      await cubit.close();
      verify(() => connectivity.dispose()).called(1);
    });
  });
}

OutboxItem _manualReviewItem() => OutboxItem(
      id: 'item-1',
      operation: OutboxOperation.labelUsage,
      endpoint: '/v1/labels/label-1/usage',
      method: 'POST',
      payload: const {},
      idempotencyKey: 'key-1',
      createdAt: DateTime(2026, 9, 1),
      status: OutboxStatus.manualReview,
    );
