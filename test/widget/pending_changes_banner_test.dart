import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/storage/outbox/outbox_item.dart';
import 'package:steriymed_mobile/core/storage/outbox/outbox_operation.dart';
import 'package:steriymed_mobile/core/storage/outbox/outbox_status.dart';
import 'package:steriymed_mobile/shared/widgets/feedback/pending_changes_banner.dart';

import '../helpers/pump_app.dart';
import '../mocks/mock_outbox_store.dart';

OutboxItem _item(String key, OutboxStatus status, {String id = 'i'}) =>
    OutboxItem(
      id: id,
      resourceKey: key,
      operation: OutboxOperation.cycleTransition,
      endpoint: '/v1/cycles/c1/start',
      method: 'POST',
      payload: const {},
      idempotencyKey: 'k-$id',
      createdAt: DateTime.utc(2026, 10, 1),
      status: status,
    );

void main() {
  late MockOutboxStore store;
  late List<OutboxItem> items;

  setUp(() {
    store = MockOutboxStore();
    items = [];
    when(() => store.all()).thenAnswer((_) => items);
    when(() => store.changes).thenAnswer((_) => const Stream<BoxEvent>.empty());
  });

  Future<void> show(
    WidgetTester tester,
    String key, {
    bool prefix = false,
  }) async {
    await pumpApp(
      tester,
      PendingChangesBanner(resourceKey: key, matchPrefix: prefix, store: store),
    );
    await tester.pump();
  }

  testWidgets('shows nothing when the record has no unsent change', (
    tester,
  ) async {
    items = [_item('cycle:other', OutboxStatus.pending)];
    await show(tester, 'cycle:c1');
    expect(find.textContaining('modification'), findsNothing);
  });

  testWidgets('says a queued change is not reflected in the data yet', (
    tester,
  ) async {
    items = [_item('cycle:c1', OutboxStatus.pending)];
    await show(tester, 'cycle:c1');
    expect(find.textContaining('en attente d’envoi'), findsOneWidget);
    expect(find.textContaining('ne l’incluent pas encore'), findsOneWidget);
  });

  testWidgets('a stuck change is flagged as unconfirmed, not as waiting', (
    tester,
  ) async {
    items = [_item('cycle:c1', OutboxStatus.unknownOutcome)];
    await show(tester, 'cycle:c1');
    expect(find.textContaining('n’a pas pu être confirmée'), findsOneWidget);
    expect(find.textContaining('en attente'), findsNothing);
  });

  testWidgets('counts several stuck changes', (tester) async {
    items = [
      _item('cycle:c1', OutboxStatus.conflict, id: 'a'),
      _item('cycle:c1', OutboxStatus.validationFailed, id: 'b'),
    ];
    await show(tester, 'cycle:c1');
    expect(find.textContaining('2 modifications'), findsOneWidget);
  });

  testWidgets('prefix mode aggregates every record of a list screen', (
    tester,
  ) async {
    items = [
      _item('stock:batch-1', OutboxStatus.pending, id: 'a'),
      _item('stock:batch-2', OutboxStatus.pending, id: 'b'),
      _item('cycle:c1', OutboxStatus.pending, id: 'c'),
    ];
    await show(tester, 'stock:', prefix: true);
    expect(find.textContaining('2 modifications'), findsOneWidget);
  });

  testWidgets('an exact key does not match a longer key of the same family', (
    tester,
  ) async {
    items = [_item('cycle:c10', OutboxStatus.pending)];
    await show(tester, 'cycle:c1');
    expect(find.textContaining('modification'), findsNothing);
  });
}
