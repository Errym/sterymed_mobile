import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steriymed_mobile/core/errors/api_exception.dart';
import 'package:steriymed_mobile/core/storage/outbox/outbox_status.dart';
import '../../helpers/queue_harness.dart';
import 'package:steriymed_mobile/features/labels/data/datasources/label_usage_remote_datasource.dart';
import 'package:steriymed_mobile/features/labels/data/repositories/label_usage_repository.dart';

void main() {
  late QueueHarness q; late LabelUsageRepository repo;
  setUp(() async {
    q = await QueueHarness.create();
    repo = LabelUsageRepository(LabelUsageRemoteDatasource(q.dio), outbox: q.store, connectivity: q.connectivity, syncStatus: q.sync);
    q.adapter.data = {'id': 'usage-1', 'label_id': 'label-1', 'patient_id': 'p1', 'practitioner_id': 'pr1', 'procedure': 'Soin', 'used_at': '2026-10-01T10:00:00Z'};
  });
  tearDown(() => q.close());
  Future<dynamic> record({DateTime? at}) => repo.recordUsage(labelId: 'label-1', patientId: 'p1', patientReference: 'REF-1', practitionerId: 'pr1', procedure: 'Soin', usedAt: at);
  test('confirmed usage uses durable transport and returns real result', () async {
    final result = await record(); expect(result.id, 'usage-1'); expect(result.isQueued, isFalse);
    expect(q.store.all(), isEmpty); expect(q.adapter.requests.single.path, '/v1/labels/label-1/usage');
  });
  test('offline usage captures occurrence time before replay', () async {
    q.online = false; final before = DateTime.now().toUtc(); final result = await record();
    final item = q.store.all().single; expect(result.isQueued, isTrue);
    final usedAt = DateTime.parse(item.payload['used_at'] as String);
    expect(usedAt.isBefore(before), isFalse); expect(usedAt, result.usedAt);
    await q.engine.flush(); expect(jsonDecode(q.adapter.requests.single.data as String)['used_at'], item.payload['used_at']);
  });
  test('explicit historical occurrence time is not replaced by replay time', () async {
    q.online = false; final at = DateTime.utc(2026, 9, 30, 23, 59);
    await record(at: at); expect(q.store.all().single.payload['used_at'], at.toIso8601String());
  });
  test('unknown result remains durable and does not report queued success', () async {
    q.adapter.failure = DioExceptionType.receiveTimeout;
    await expectLater(record(), throwsA(isA<ApiException>())); expect(q.store.all().single.status, OutboxStatus.unknownOutcome);
    await expectLater(record(), throwsA(isA<ApiException>())); expect(q.adapter.requests, hasLength(1));
  });
  test('permission rejection preserves intent for review and surfaces error', () async {
    q.adapter.status = 403; await expectLater(record(), throwsA(isA<ApiException>()));
    expect(q.store.all().single.status, OutboxStatus.permissionDenied);
  });
}
