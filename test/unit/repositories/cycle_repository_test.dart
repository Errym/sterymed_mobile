import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/cache/cache.dart';
import 'package:steriymed_mobile/core/errors/api_exception.dart';
import 'package:steriymed_mobile/core/storage/outbox/outbox_item.dart';
import 'package:steriymed_mobile/core/storage/outbox/outbox_operation.dart';
import 'package:steriymed_mobile/features/cycles/data/datasources/cycle_remote_datasource.dart';
import 'package:steriymed_mobile/features/cycles/data/models/cycle_data.dart';
import 'package:steriymed_mobile/features/cycles/data/models/cycle_release_data.dart';
import 'package:steriymed_mobile/features/cycles/data/repositories/cycle_repository.dart';
import 'package:steriymed_mobile/features/cycles/data/repositories/device_program_repository.dart';
import 'package:steriymed_mobile/features/cycles/data/repositories/device_repository.dart';

import '../../mocks/mock_connectivity.dart';
import '../../mocks/mock_outbox_store.dart';
import '../../mocks/mock_sync_status_cubit.dart';

class MockCycleRemoteDatasource extends Mock implements CycleRemoteDatasource {}
class MockDeviceRepository extends Mock implements DeviceRepository {}
class MockDeviceProgramRepository extends Mock
    implements DeviceProgramRepository {}

void main() {
  late MockCycleRemoteDatasource remote;
  late MockDeviceRepository devices;
  late MockDeviceProgramRepository programs;
  late MockOutboxStore outbox;
  late MockConnectivityService connectivity;
  late MockSyncStatusCubit syncStatus;
  late CycleRepository repo;

  const networkError = ApiException(
    code: 'network_error',
    message: 'no connection',
  );
  const validationError = ApiException(
    code: 'validation_error',
    message: 'bad input',
    statusCode: 422,
  );

  CycleData onlineResult(String status) => CycleData(
        id: 'cycle-1',
        number: 'CT-000001',
        status: status,
        deviceId: 'device-1',
        deviceName: 'Autoclave A',
        createdAt: DateTime(2026, 1, 1),
      );

  setUpAll(() {
    registerFallbackValue(
      OutboxItem(
        id: 'fallback',
        operation: OutboxOperation.cycleTransition,
        endpoint: '/x',
        method: 'POST',
        payload: const {},
        idempotencyKey: 'fallback-key',
        createdAt: DateTime(2026, 1, 1),
      ),
    );
  });

  setUp(() {
    remote = MockCycleRemoteDatasource();
    devices = MockDeviceRepository();
    programs = MockDeviceProgramRepository();
    outbox = MockOutboxStore();
    connectivity = MockConnectivityService();
    syncStatus = MockSyncStatusCubit();
    repo = CycleRepository(
      remote,
      AppCache(),
      devices,
      programs,
      outbox: outbox,
      connectivity: connectivity,
      syncStatus: syncStatus,
    );

    when(() => outbox.enqueue(any())).thenAnswer((_) async {});
    when(() => syncStatus.refreshNow()).thenAnswer((_) async {});
  });

  group('start() — online-first with offline outbox fallback', () {
    test('online success returns the enriched remote result without touching the outbox',
        () async {
      when(() => connectivity.isConnected).thenAnswer((_) async => true);
      when(() => remote.start('cycle-1'))
          .thenAnswer((_) async => onlineResult('in_progress'));

      final result = await repo.start('cycle-1');

      expect(result.status, 'in_progress');
      expect(result.deviceName, 'Autoclave A');
      verifyNever(() => outbox.enqueue(any()));
      verifyNever(() => syncStatus.refreshNow());
    });

    test('a network ApiException while online falls through to the outbox',
        () async {
      when(() => connectivity.isConnected).thenAnswer((_) async => true);
      when(() => remote.start('cycle-1')).thenThrow(networkError);

      final result = await repo.start('cycle-1');

      expect(result.id, isNotEmpty);
      expect(result.status, 'in_progress');
      final captured =
          verify(() => outbox.enqueue(captureAny())).captured.single
              as OutboxItem;
      expect(captured.operation, OutboxOperation.cycleTransition);
      expect(captured.endpoint, '/v1/cycles/cycle-1/start');
      verify(() => syncStatus.refreshNow()).called(1);
    });

    test('being offline enqueues directly without calling the remote datasource',
        () async {
      when(() => connectivity.isConnected).thenAnswer((_) async => false);

      final result = await repo.start('cycle-1');

      expect(result.status, 'in_progress');
      verifyNever(() => remote.start(any()));
      verify(() => outbox.enqueue(any())).called(1);
      verify(() => syncStatus.refreshNow()).called(1);
    });

    test('a non-network ApiException (e.g. validation) is rethrown, not queued',
        () async {
      when(() => connectivity.isConnected).thenAnswer((_) async => true);
      when(() => remote.start('cycle-1')).thenThrow(validationError);

      await expectLater(
        () => repo.start('cycle-1'),
        throwsA(isA<ApiException>()),
      );
      verifyNever(() => outbox.enqueue(any()));
      verifyNever(() => syncStatus.refreshNow());
    });
  });

  group('release() — online-first with offline outbox fallback', () {
    test('online success returns the real release decision', () async {
      when(() => connectivity.isConnected).thenAnswer((_) async => true);
      when(() => remote.release('cycle-1', decision: 'compliant', reason: null))
          .thenAnswer((_) async => CycleReleaseData(
                id: 'rel-1',
                cycleId: 'cycle-1',
                decision: CycleReleaseDecision.compliant,
                releasedAt: DateTime(2026, 1, 1),
              ));

      final result =
          await repo.release('cycle-1', decision: 'compliant', reason: null);

      expect(result.decision, CycleReleaseDecision.compliant);
      verifyNever(() => outbox.enqueue(any()));
    });

    test('offline queues the decision and reason, returning a matching synthetic result',
        () async {
      when(() => connectivity.isConnected).thenAnswer((_) async => false);

      final result = await repo.release(
        'cycle-1',
        decision: 'rejected',
        reason: 'Test biologique non conforme',
      );

      expect(result.decision, CycleReleaseDecision.rejected);
      expect(result.reason, 'Test biologique non conforme');
      final captured =
          verify(() => outbox.enqueue(captureAny())).captured.single
              as OutboxItem;
      expect(captured.payload['decision'], 'rejected');
      expect(captured.payload['reason'], 'Test biologique non conforme');
      verify(() => syncStatus.refreshNow()).called(1);
    });
  });
}
