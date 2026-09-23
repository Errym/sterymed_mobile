import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:steriymed_mobile/core/storage/outbox/outbox_item.dart';
import 'package:steriymed_mobile/core/storage/outbox/outbox_operation.dart';
import 'package:steriymed_mobile/core/storage/outbox/outbox_status.dart';
import 'package:steriymed_mobile/core/storage/outbox/outbox_store.dart';

import '../../fixtures/outbox_item_fixture.dart';

void main() {
  late Directory tempDir;
  late Box<dynamic> box;
  late OutboxStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('outbox_store_test');
    Hive.init(tempDir.path);
    box = await Hive.openBox('outbox_store_test');
    store = OutboxStore(box);
  });

  tearDown(() async {
    await box.close();
    await Hive.deleteBoxFromDisk('outbox_store_test');
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('all() is empty for a fresh store', () {
    expect(store.all(), isEmpty);
  });

  test('enqueue then all() returns the item', () async {
    final item = buildOutboxItem(id: 'a');
    await store.enqueue(item);

    final all = store.all();
    expect(all, hasLength(1));
    expect(all.single.id, 'a');
    expect(all.single.operation, OutboxOperation.stockIssue);
  });

  test('all() sorts items by createdAt ascending regardless of insert order',
      () async {
    final older = buildOutboxItem(id: 'older').copyWith();
    final newer = buildOutboxItem(id: 'newer');
    final olderWithDate = OutboxItem(
      id: older.id,
      operation: older.operation,
      endpoint: older.endpoint,
      method: older.method,
      payload: older.payload,
      idempotencyKey: older.idempotencyKey,
      createdAt: DateTime(2026, 1, 1),
    );
    final newerWithDate = OutboxItem(
      id: newer.id,
      operation: newer.operation,
      endpoint: newer.endpoint,
      method: newer.method,
      payload: newer.payload,
      idempotencyKey: newer.idempotencyKey,
      createdAt: DateTime(2026, 6, 1),
    );

    await store.enqueue(newerWithDate);
    await store.enqueue(olderWithDate);

    final all = store.all();
    expect(all.map((i) => i.id).toList(), ['older', 'newer']);
  });

  test('pending() only returns items with pending status', () async {
    await store.enqueue(buildOutboxItem(id: 'p1', status: OutboxStatus.pending));
    await store.enqueue(
      buildOutboxItem(id: 'r1', status: OutboxStatus.manualReview),
    );
    await store.enqueue(buildOutboxItem(id: 'p2', status: OutboxStatus.pending));

    final pending = store.pending();
    expect(pending.map((i) => i.id).toSet(), {'p1', 'p2'});
  });

  test('manualReview() only returns items flagged for manual review',
      () async {
    await store.enqueue(buildOutboxItem(id: 'p1', status: OutboxStatus.pending));
    await store.enqueue(
      buildOutboxItem(id: 'r1', status: OutboxStatus.manualReview),
    );

    final review = store.manualReview();
    expect(review.map((i) => i.id).toList(), ['r1']);
  });

  test('pendingCount reflects only pending items', () async {
    await store.enqueue(buildOutboxItem(id: 'p1', status: OutboxStatus.pending));
    await store.enqueue(buildOutboxItem(id: 'p2', status: OutboxStatus.pending));
    await store.enqueue(
      buildOutboxItem(id: 'r1', status: OutboxStatus.manualReview),
    );

    expect(store.pendingCount, 2);
  });

  test('update() overwrites the stored item for the same id', () async {
    final item = buildOutboxItem(id: 'a', status: OutboxStatus.pending);
    await store.enqueue(item);

    await store.update(item.copyWith(status: OutboxStatus.manualReview));

    final all = store.all();
    expect(all, hasLength(1));
    expect(all.single.status, OutboxStatus.manualReview);
  });

  test('remove() deletes only the targeted item', () async {
    await store.enqueue(buildOutboxItem(id: 'a'));
    await store.enqueue(buildOutboxItem(id: 'b'));

    await store.remove('a');

    final all = store.all();
    expect(all.map((i) => i.id).toList(), ['b']);
  });

  test('clear() empties the store', () async {
    await store.enqueue(buildOutboxItem(id: 'a'));
    await store.enqueue(buildOutboxItem(id: 'b'));

    await store.clear();

    expect(store.all(), isEmpty);
  });
}
