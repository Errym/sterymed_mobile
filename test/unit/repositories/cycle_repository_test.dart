import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steriymed_mobile/core/errors/api_exception.dart';
import 'package:steriymed_mobile/core/storage/outbox/outbox_status.dart';
import '../../helpers/queue_harness.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/cache/cache.dart';
import 'package:steriymed_mobile/features/cycles/data/datasources/cycle_remote_datasource.dart';
import 'package:steriymed_mobile/features/cycles/data/repositories/cycle_repository.dart';
import 'package:steriymed_mobile/features/cycles/data/repositories/device_repository.dart';
import 'package:steriymed_mobile/features/cycles/data/repositories/device_program_repository.dart';
import 'package:steriymed_mobile/features/cycles/data/models/cycle_release_data.dart';
class Devices extends Mock implements DeviceRepository {}
class Programs extends Mock implements DeviceProgramRepository {}
void main() {
  late QueueHarness q; late CycleRepository repo;
  setUp(() async {
    q = await QueueHarness.create(); final devices = Devices(); final programs = Programs();
    when(() => devices.list()).thenAnswer((_) async => []);
    repo = CycleRepository(CycleRemoteDatasource(q.dio), AppCache(), devices, programs, outbox: q.store, connectivity: q.connectivity, syncStatus: q.sync);
    q.adapter.data = {'id': 'cycle-1', 'cycle_number': 7, 'status': 'running', 'device_id': 'device-1', 'device_name': 'Autoclave A', 'created_at': '2026-10-01T10:00:00Z'};
  });
  tearDown(() => q.close());
  test('confirmed start returns real normalized state', () async {
    final result = await repo.start('cycle-1'); expect(result.status, 'in_progress');
    expect(result.isQueued, isFalse); expect(q.store.all(), isEmpty);
  });
  test('offline start stores intent and marks synthetic result pending', () async {
    q.online = false; final result = await repo.start('cycle-1');
    expect(result.isQueued, isTrue); expect(q.store.all().single.endpoint, '/v1/cycles/cycle-1/start');
  });
  test('lost start response cannot manufacture another transition', () async {
    q.adapter.failure = DioExceptionType.receiveTimeout;
    await expectLater(repo.start('cycle-1'), throwsA(isA<ApiException>()));
    await expectLater(repo.start('cycle-1'), throwsA(isA<ApiException>())); expect(q.adapter.requests, hasLength(1));
  });
  test('rejected transition preserves record and surfaces validation', () async {
    q.adapter.status = 422; await expectLater(repo.start('cycle-1'), throwsA(isA<ApiException>()));
    expect(q.store.all().single.status, OutboxStatus.validationFailed);
  });
  test('online release returns confirmed server decision', () async {
    q.adapter.data = {'id': 'release-1', 'cycle_id': 'cycle-1', 'decision': 'compliant', 'released_at': '2026-10-01T10:00:00Z'};
    final result = await repo.release('cycle-1', decision: 'compliant');
    expect(result.decision, CycleReleaseDecision.compliant); expect(result.isQueued, isFalse);
  });
  test('offline release requires fresh online confirmation and does not enqueue', () async {
    q.online = false;
    await expectLater(repo.release('cycle-1', decision: 'rejected', reason: 'Failed control'), throwsA(isA<ApiException>()));
    expect(q.store.all(), isEmpty); expect(q.adapter.requests, isEmpty);
  });
}
