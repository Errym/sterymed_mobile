import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steriymed_mobile/core/errors/api_exception.dart';
import 'package:steriymed_mobile/core/storage/outbox/outbox_operation.dart';
import 'package:steriymed_mobile/core/storage/outbox/outbox_item.dart';
import 'package:steriymed_mobile/core/storage/outbox/outbox_status.dart';
import '../../helpers/queue_harness.dart';

void main() {
  late QueueHarness q;
  var clock = DateTime.utc(2026, 10, 1);
  setUp(() async { clock = DateTime.utc(2026, 10, 1); q = await QueueHarness.create(now: () => clock); });
  tearDown(() => q.close());
  Future<dynamic> submit({bool online = true, bool release = false}) => q.engine.submit(
    operation: OutboxOperation.stockIssue, endpoint: '/v1/stock-movements/issue',
    payload: {'batch_id': 'batch-A', 'qty': 2}, resourceKey: 'stock:batch-A', online: online, requireOnline: release);

  test('durable owner, key and exact body exist before first network byte', () async {
    q.adapter.beforeReply = (request) async {
      final item = q.store.all().single;
      expect(item.status, OutboxStatus.syncing); expect(item.ownerScope, 'fixture/A');
      expect(item.encodedPayload, request.data); expect(jsonDecode(request.data as String)['qty'], 2);
      expect(item.idempotencyKey, request.headers['Idempotency-Key']); expect(item.firstAttemptAt, clock);
    };
    final result = await submit(); expect(result.confirmed, isTrue); expect(q.store.all(), isEmpty);
  });
  test('concurrent duplicate taps share one operation and one request', () async {
    final gate = Completer<void>(); q.adapter.beforeReply = (_) => gate.future;
    final a = submit(); final b = submit(); await q.untilRequested();
    expect(q.adapter.requests, hasLength(1)); expect(q.engine.isFlushing, isTrue);
    gate.complete(); final results = await Future.wait([a, b]);
    expect(results[0].item.id, results[1].item.id); expect(q.engine.isFlushing, isFalse);
  });
  test('offline queue preserves its key/body and automatic/manual workers serialize', () async {
    final pending = await submit(online: false); expect(q.adapter.requests, isEmpty);
    final gate = Completer<void>(); q.adapter.beforeReply = (_) => gate.future;
    final first = q.engine.flush(); final second = q.engine.flush(); final third = q.engine.retryOne(pending.item.id);
    await q.untilRequested(); expect(q.adapter.requests, hasLength(1));
    gate.complete(); await first; await second; await third;
    expect(q.adapter.requests.single.headers['Idempotency-Key'], pending.item.idempotencyKey);
    expect(q.store.all(), isEmpty);
  });
  test('commit then lost response keeps unknown outcome and never silently resends', () async {
    var committed = 0; q.adapter.beforeReply = (_) async { committed++; };
    q.adapter.failure = DioExceptionType.receiveTimeout;
    final attempt = await submit(); expect(attempt.error, isA<ApiException>());
    expect(q.store.all().single.status, OutboxStatus.unknownOutcome);
    await q.engine.flush(); await q.engine.retryOne(attempt.item.id);
    await expectLater(submit(), throwsA(isA<ApiException>())); expect(committed, 1);
  });
  test('interrupted sending state is recovered as unknown after restart', () async {
    final pending = await submit(online: false);
    await q.store.update((pending.item as OutboxItem).copyWith(status: OutboxStatus.syncing, firstAttemptAt: clock));
    await q.engine.flush(); expect(q.adapter.requests, isEmpty);
    expect(q.store.all().single.status, OutboxStatus.unknownOutcome);
  });
  for (final entry in {401: OutboxStatus.authBlocked, 403: OutboxStatus.permissionDenied,
    409: OutboxStatus.conflict, 422: OutboxStatus.validationFailed, 500: OutboxStatus.unknownOutcome}.entries) {
    test('${entry.key} preserves record in distinct ${entry.value.name} state', () async {
      q.adapter.status = entry.key; final result = await submit();
      expect(result.confirmed, isFalse); expect(q.store.all().single.status, entry.value);
      expect(q.store.all().single.idempotencyKey, q.adapter.requests.single.headers['Idempotency-Key']);
    });
  }
  test('429 honors persisted Retry-After before retrying the same operation', () async {
    q.adapter.status = 429; q.adapter.retryAfter = 120;
    final result = await submit(); expect(q.store.all().single.nextAttemptAt, clock.add(const Duration(seconds: 120)));
    await q.engine.retryOne(result.item.id); await q.engine.flush(); expect(q.adapter.requests, hasLength(1));
    clock = clock.add(const Duration(seconds: 120)); q.adapter.status = 200;
    await q.engine.flush(); expect(q.adapter.requests, hasLength(2));
    expect(q.adapter.requests[0].data, q.adapter.requests[1].data);
    expect(q.adapter.requests[0].headers['Idempotency-Key'], q.adapter.requests[1].headers['Idempotency-Key']);
  });
  test('retry window expiry requires reconciliation without sending', () async {
    final result = await submit(online: false);
    await q.store.update((result.item as OutboxItem).copyWith(firstAttemptAt: clock.subtract(kReplayWindow + const Duration(days: 1))));
    await q.engine.flush(); expect(q.adapter.requests, isEmpty); expect(q.store.all().single.status, OutboxStatus.unknownOutcome);
  });
  test('online-only decisions are not queued offline and cannot auto-replay', () async {
    await expectLater(submit(online: false, release: true), throwsA(isA<ApiException>())); expect(q.store.all(), isEmpty);
    q.adapter.failure = DioExceptionType.receiveTimeout; await submit(release: true);
    await q.engine.flush(); expect(q.adapter.requests, hasLength(1));
  });
  test('malformed successful confirmation is retained for verification', () async {
    q.adapter.data = {'unexpected': true}; final result = await submit();
    expect(result.confirmed, isFalse); expect(q.store.all().single.status, OutboxStatus.unknownOutcome);
  });
  test('another intent on an unresolved resource cannot create a second write', () async {
    await submit(online: false);
    await expectLater(q.engine.submit(operation: OutboxOperation.stockAdjust,
      endpoint: '/v1/stock-movements/adjust', payload: {'qty': 99}, resourceKey: 'stock:batch-A', online: true),
      throwsA(isA<ApiException>())); expect(q.store.all(), hasLength(1)); expect(q.adapter.requests, isEmpty);
  });
}
