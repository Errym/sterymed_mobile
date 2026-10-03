// Phase 1 gate: a phone that was off with a large queue must open its local
// store quickly and keep every item. 500 queued writes is the roadmap's bar.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:steriymed_mobile/core/storage/outbox/outbox_store.dart';

import '../../fixtures/outbox_item_fixture.dart';

void main() {
  test('opening a store holding 500 items is fast and loses nothing', () async {
    final dir = await Directory.systemTemp.createTemp('cold_boot_outbox');
    Hive.init(dir.path);
    var box = await Hive.openBox('cold_boot');
    final seed = OutboxStore(box);
    for (var i = 0; i < 500; i++) {
      await seed.enqueue(buildOutboxItem(id: 'item-$i'));
    }
    await box.close();

    final watch = Stopwatch()..start();
    box = await Hive.openBox('cold_boot');
    final store = OutboxStore(box);
    final items = store.all();
    watch.stop();

    expect(items, hasLength(500));
    expect(watch.elapsedMilliseconds, lessThan(500));

    await box.close();
    await Hive.deleteBoxFromDisk('cold_boot');
    await dir.delete(recursive: true);
  });
}
