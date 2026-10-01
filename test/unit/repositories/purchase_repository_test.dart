import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steriymed_mobile/core/errors/api_exception.dart';
import 'package:steriymed_mobile/core/storage/outbox/outbox_status.dart';
import '../../helpers/queue_harness.dart';
import 'package:steriymed_mobile/core/cache/cache.dart';
import 'package:steriymed_mobile/features/purchases/data/datasources/purchase_remote_datasource.dart';
import 'package:steriymed_mobile/features/purchases/data/repositories/purchase_repository.dart';

void main() {
  late QueueHarness q; late PurchaseRepository repo; late AppCache cache;
  final lines = [{'purchase_order_line_id': 'line-1', 'qty': 5, 'batch_number': 'LOT-1', 'expiry_date': '2027-01-01'}];
  setUp(() async {
    q = await QueueHarness.create(); cache = AppCache();
    repo = PurchaseRepository(PurchaseRemoteDatasource(q.dio), cache, outbox: q.store, connectivity: q.connectivity, syncStatus: q.sync);
    q.adapter.data = {'id': 'receipt-1', 'purchase_order_id': 'po-1', 'received_at': '2026-10-01T10:00:00Z'};
  });
  tearDown(() => q.close());
  Future<dynamic> receive() => repo.receive(poId: 'po-1', locationId: 'loc-1', lines: lines);
  test('confirmed receipt invalidates stock and order caches', () async {
    cache.put('stock_levels', ['old']); final result = await receive();
    expect(result.id, 'receipt-1'); expect(result.isQueued, isFalse); expect(cache.get('stock_levels'), isNull);
  });
  test('offline receipt preserves complete line payload and is explicitly pending', () async {
    q.online = false; final result = await receive(); expect(result.isQueued, isTrue);
    final payload = q.store.all().single.payload; expect(payload['location_id'], 'loc-1'); expect(payload['lines'], lines);
    await q.engine.flush(); expect(jsonDecode(q.adapter.requests.single.data as String)['lines'], lines);
  });
  test('timeout retains the same uncertain operation instead of new-key fallback', () async {
    q.adapter.failure = DioExceptionType.receiveTimeout;
    await expectLater(receive(), throwsA(isA<ApiException>())); expect(q.store.all().single.status, OutboxStatus.unknownOutcome);
    await expectLater(receive(), throwsA(isA<ApiException>())); expect(q.adapter.requests, hasLength(1));
  });
  test('422 retains rejected receipt and surfaces validation to the form', () async {
    q.adapter.status = 422; await expectLater(receive(), throwsA(isA<ApiException>()));
    expect(q.store.all().single.status, OutboxStatus.validationFailed);
  });
}
