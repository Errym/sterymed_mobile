import 'dart:convert';
import 'dart:typed_data';

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
  test('editing an item is ONE in-place PATCH: no delete, no create, batch untouched', () async {
    q.adapter.data = {'id': 'item-1', 'cycle_id': 'cycle-1', 'batch_id': 'b-1', 'batch_number': 'LOT1', 'description': 'Kit révisé', 'sequence_in_cycle': 2, 'created_at': '2026-10-01T10:00:00Z'};
    final item = await repo.updateItem('cycle-1', 'item-1', {'description': 'Kit révisé'});
    expect(item.id, 'item-1'); expect(item.batchId, 'b-1');
    expect(q.adapter.requests, hasLength(1));
    final request = q.adapter.requests.single;
    expect(request.method, 'PATCH'); expect(request.path, '/v1/cycles/cycle-1/items/item-1');
    expect(request.data, {'description': 'Kit révisé'});
  });
  test('a refused item edit surfaces the error and sends nothing else', () async {
    q.adapter.status = 409;
    await expectLater(repo.updateItem('cycle-1', 'item-1', {'description': 'X'}), throwsA(isA<ApiException>()));
    expect(q.adapter.requests, hasLength(1));
  });
  test('an attachment goes up as JSON base64 (the multipart route 500s), once', () async {
    q.adapter.data = {'id': 'att-1', 'file_name': 'p.png', 'mime_type': 'image/png', 'size': 3, 'url': 'http://x/p.png'};
    final bytes = Uint8List.fromList([1, 2, 3]);
    final sent = <int>[];
    final att = await repo.uploadAttachment(cycleId: 'cycle-1', fileName: 'p.png', bytes: bytes, mimeType: 'image/png', onProgress: (s, t) => sent.add(s));
    expect(att.id, 'att-1');
    expect(q.adapter.requests, hasLength(1));
    final request = q.adapter.requests.single;
    expect(request.method, 'POST'); expect(request.path, '/v1/cycles/cycle-1/attachments-base64');
    final body = request.data as Map; expect(body['file_name'], 'p.png'); expect(base64Decode(body['file_data'] as String), bytes);
  });
  test('an empty or oversized attachment is refused before any request', () async {
    await expectLater(repo.uploadAttachment(cycleId: 'cycle-1', fileName: 'e.png', bytes: Uint8List(0)), throwsA(isA<ApiException>()));
    await expectLater(repo.uploadAttachment(cycleId: 'cycle-1', fileName: 'big.png', bytes: Uint8List(10 * 1024 * 1024 + 1)), throwsA(isA<ApiException>()));
    expect(q.adapter.requests, isEmpty);
  });
}
