// Phase 2 proofs: the engine honours the session (the production wiring),
// and every stuck queue state has a deliberate, safe way out.
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steriymed_mobile/core/storage/outbox/outbox_item.dart';
import 'package:steriymed_mobile/core/storage/outbox/outbox_operation.dart';
import 'package:steriymed_mobile/core/storage/outbox/outbox_status.dart';
import 'package:steriymed_mobile/core/storage/outbox/sync_result.dart';
import 'package:steriymed_mobile/core/storage/secure_storage.dart';
import 'package:steriymed_mobile/core/storage/session_store.dart';

import '../../helpers/queue_harness.dart';

class _MemorySecure extends SecureStorage {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}

Future<void> _login(SessionStore session, String name) async {
  final generation = session.beginReplacement();
  await session.commit(
    generation: generation,
    token: 'token-$name',
    user: {
      'id': name,
      'permissions': ['inventory.manage'],
    },
    tenant: {'id': 'clinic-$name'},
  );
}

void main() {
  late DateTime clock;
  late SessionStore session;
  late QueueHarness q;
  var confirmed = 0;

  setUp(() async {
    clock = DateTime.utc(2026, 10, 1, 8);
    confirmed = 0;
    session = SessionStore(_MemorySecure());
    await _login(session, 'A');
    q = await QueueHarness.create(
      now: () => clock,
      session: session,
      onConfirmed: () => confirmed++,
    );
  });
  tearDown(() async {
    await q.close();
    await session.dispose();
  });

  Future<dynamic> submit({bool online = true}) => q.engine.submit(
    operation: OutboxOperation.stockIssue,
    endpoint: '/v1/stock-movements/issue',
    payload: {'batch_id': 'batch-A', 'qty': 2},
    resourceKey: 'stock:batch-A',
    online: online,
  );

  // Leaves one item in `unknownOutcome` (response lost after the request left).
  Future<OutboxItem> makeUnknown() async {
    q.adapter.failure = DioExceptionType.receiveTimeout;
    await submit();
    q.adapter.failure = null;
    final item = q.store.all().single;
    expect(item.status, OutboxStatus.unknownOutcome);
    return item;
  }

  group('session fencing is active in the engine', () {
    test(
      'a confirmed write notifies so list caches can be invalidated',
      () async {
        await submit();
        expect(confirmed, 1);
      },
    );

    test(
      'a restored, not-yet-validated session can neither queue nor send',
      () async {
        final secure = _MemorySecure();
        final first = SessionStore(secure);
        await _login(first, 'A');
        final restored = SessionStore(secure);
        await restored.load(); // restored sessions must be re-validated first
        expect(restored.canSend, isFalse);

        final harness = await QueueHarness.create(
          now: () => clock,
          session: restored,
        );
        addTearDown(() async {
          await harness.close();
          await first.dispose();
          await restored.dispose();
        });

        await expectLater(
          harness.engine.submit(
            operation: OutboxOperation.stockIssue,
            endpoint: '/v1/stock-movements/issue',
            payload: {'batch_id': 'batch-A', 'qty': 2},
            resourceKey: 'stock:batch-A',
            online: true,
          ),
          throwsA(
            isA<Object>().having(
              (e) => e.toString(),
              'message',
              contains('session_validation_required'),
            ),
          ),
        );
        expect(await harness.engine.flush(), 0);
        expect(harness.adapter.requests, isEmpty);
      },
    );

    test(
      'a response arriving after the session changed is not recorded',
      () async {
        final gate = Completer<void>();
        q.adapter.beforeReply = (_) => gate.future;
        final inFlight = submit();
        await q.untilRequested();
        await _login(session, 'B'); // another user takes over the phone
        gate.complete();
        await inFlight;

        // Nothing was removed or marked under B; A's item is preserved hidden.
        expect(q.store.all(), isEmpty);
        expect(confirmed, 0);
      },
    );

    test(
      'while no session can send, flush does nothing and keeps the queue',
      () async {
        await submit(online: false);
        final generation = session.beginReplacement(); // logged out
        expect(generation, greaterThan(0));
        expect(await q.engine.flush(), 0);
        expect(q.adapter.requests, isEmpty);
      },
    );
  });

  group('resolving stuck items', () {
    test(
      'resend reuses the same key and body inside the replay window',
      () async {
        final stuck = await makeUnknown();
        expect(stuck.canResend(clock), isTrue);

        final result = await q.engine.resendUnknown(stuck.id);

        expect(result, SyncResult.success);
        expect(q.store.all(), isEmpty);
        expect(q.adapter.requests, hasLength(2));
        expect(
          q.adapter.requests.last.headers['Idempotency-Key'],
          stuck.idempotencyKey,
        );
        expect(q.adapter.requests.last.data, stuck.encodedPayload);
        expect(confirmed, 1);
      },
    );

    test(
      'resend is refused after the replay window and sends nothing',
      () async {
        final stuck = await makeUnknown();
        clock = clock.add(kReplayWindow + const Duration(minutes: 1));
        expect(stuck.canResend(clock), isFalse);

        final result = await q.engine.resendUnknown(stuck.id);

        expect(result, SyncResult.manualReview);
        expect(q.adapter.requests, hasLength(1), reason: 'no extra request');
        expect(q.store.find(stuck.id)!.status, OutboxStatus.unknownOutcome);
      },
    );

    test('a failed resend stays unresolved and keeps the same key', () async {
      final stuck = await makeUnknown();
      q.adapter.failure = DioExceptionType.receiveTimeout;
      final result = await q.engine.resendUnknown(stuck.id);
      q.adapter.failure = null;

      expect(result, SyncResult.manualReview);
      final after = q.store.find(stuck.id)!;
      expect(after.status, OutboxStatus.unknownOutcome);
      expect(after.idempotencyKey, stuck.idempotencyKey);
    });

    test('abandon removes the item and unblocks the record', () async {
      final stuck = await makeUnknown();
      // The unresolved item blocks any new action on the same resource.
      await expectLater(
        q.engine.submit(
          operation: OutboxOperation.stockIssue,
          endpoint: '/v1/stock-movements/issue',
          payload: {'batch_id': 'batch-A', 'qty': 5},
          resourceKey: 'stock:batch-A',
          online: true,
        ),
        throwsA(
          isA<Object>().having(
            (e) => e.toString(),
            'message',
            contains('operation_unresolved'),
          ),
        ),
      );

      expect(await q.engine.abandon(stuck.id), isTrue);
      expect(q.store.all(), isEmpty);

      final next = await q.engine.submit(
        operation: OutboxOperation.stockIssue,
        endpoint: '/v1/stock-movements/issue',
        payload: {'batch_id': 'batch-A', 'qty': 5},
        resourceKey: 'stock:batch-A',
        online: true,
      );
      expect(next.confirmed, isTrue);
    });

    test('abandon refuses an item that is being sent right now', () async {
      final gate = Completer<void>();
      q.adapter.beforeReply = (_) => gate.future;
      final inFlight = submit();
      await q.untilRequested();
      final id = q.store.all().single.id;

      expect(await q.engine.abandon(id), isFalse);

      gate.complete();
      await inFlight;
    });

    for (final status in [
      OutboxStatus.conflict,
      OutboxStatus.validationFailed,
      OutboxStatus.permissionDenied,
    ]) {
      test('${status.name} can only be abandoned, never resent', () async {
        final stuck = await makeUnknown();
        await q.store.update(stuck.copyWith(status: status));

        expect(q.store.find(stuck.id)!.canResend(clock), isFalse);
        expect(await q.engine.resendUnknown(stuck.id), SyncResult.manualReview);
        expect(await q.engine.abandon(stuck.id), isTrue);
        expect(q.store.all(), isEmpty);
      });
    }
  });
}
