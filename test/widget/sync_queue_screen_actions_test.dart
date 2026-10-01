import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/storage/key_value_store.dart';
import 'package:steriymed_mobile/core/storage/outbox/outbox_item.dart';
import 'package:steriymed_mobile/core/storage/outbox/outbox_operation.dart';
import 'package:steriymed_mobile/core/storage/outbox/outbox_status.dart';
import 'package:steriymed_mobile/core/storage/outbox/sync_engine.dart';
import 'package:steriymed_mobile/core/storage/outbox/sync_result.dart';
import 'package:steriymed_mobile/core/storage/outbox/outbox_store.dart';
import 'package:steriymed_mobile/core/storage/session_store.dart';
import 'package:steriymed_mobile/core/sync/sync_status_cubit.dart';
import 'package:steriymed_mobile/features/sync/presentation/screens/sync_queue_screen.dart';

import '../helpers/pump_app.dart';
import '../mocks/mock_outbox_store.dart';
import '../mocks/mock_sync_status_cubit.dart';

class _MockEngine extends Mock implements SyncEngine {}

class _MockKv extends Mock implements KeyValueStore {}

class _MockSession extends Mock implements SessionStore {}

OutboxItem _item(OutboxStatus status, {String id = 'item-1'}) => OutboxItem(
  id: id,
  ownerScope: 'owner',
  operation: OutboxOperation.stockIssue,
  endpoint: '/v1/stock-movements/issue',
  method: 'POST',
  payload: const {'qty': 1},
  idempotencyKey: 'key-$id',
  createdAt: DateTime.now().toUtc(),
  firstAttemptAt: DateTime.now().toUtc(),
  status: status,
  lastError: status == OutboxStatus.pending ? null : 'erreur',
);

void main() {
  late MockOutboxStore store;
  late _MockEngine engine;
  late MockSyncStatusCubit cubit;
  late List<OutboxItem> items;

  setUp(() {
    final di = GetIt.instance;
    di.reset();
    store = MockOutboxStore();
    engine = _MockEngine();
    cubit = MockSyncStatusCubit();
    final kv = _MockKv();
    final session = _MockSession();
    items = [];
    when(() => store.all()).thenAnswer((_) => items);
    when(() => store.recoveryRequired).thenReturn(false);
    when(() => store.quarantineCount).thenReturn(0);
    when(() => kv.recoveryRequired).thenReturn(false);
    when(() => kv.quarantineCount).thenReturn(0);
    when(() => session.userName).thenReturn('Dr Test');
    when(() => session.tenantName).thenReturn('Cabinet');
    when(() => cubit.refreshNow()).thenAnswer((_) async {});
    di
      ..registerSingleton<OutboxStore>(store)
      ..registerSingleton<SyncEngine>(engine)
      ..registerSingleton<KeyValueStore>(kv)
      ..registerSingleton<SessionStore>(session)
      ..registerSingleton<SyncStatusCubit>(cubit);
  });
  tearDown(() => GetIt.instance.reset());

  Future<void> open(WidgetTester tester) async {
    await pumpApp(tester, const SyncQueueScreen());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('unknown outcome offers Renvoyer and Abandonner', (tester) async {
    items = [_item(OutboxStatus.unknownOutcome)];
    await open(tester);

    expect(find.text('Renvoyer'), findsOneWidget);
    expect(find.text('Abandonner'), findsOneWidget);
    expect(find.text('Réessayer'), findsNothing);
  });

  testWidgets('validation failure can only be abandoned', (tester) async {
    items = [_item(OutboxStatus.validationFailed)];
    await open(tester);

    expect(find.text('Abandonner'), findsOneWidget);
    expect(find.text('Renvoyer'), findsNothing);
  });

  testWidgets('a pending item keeps the plain retry action', (tester) async {
    items = [_item(OutboxStatus.pending)];
    await open(tester);

    expect(find.text('Réessayer'), findsWidgets);
    expect(find.text('Abandonner'), findsNothing);
  });

  testWidgets('abandoning asks first and warns about the loss', (tester) async {
    items = [_item(OutboxStatus.unknownOutcome)];
    when(() => engine.abandon('item-1')).thenAnswer((_) async => true);
    await open(tester);

    await tester.tap(find.text('Abandonner'));
    await tester.pumpAndSettle();
    expect(find.text('Abandonner cette action ?'), findsOneWidget);
    expect(find.textContaining('ne sera jamais enregistrée'), findsOneWidget);
    verifyNever(() => engine.abandon(any()));

    // Cancel: nothing is removed.
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    verifyNever(() => engine.abandon(any()));

    // Confirm: the engine is asked to remove exactly that item.
    await tester.tap(find.text('Abandonner'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abandonner').last);
    await tester.pumpAndSettle();
    verify(() => engine.abandon('item-1')).called(1);
  });

  testWidgets('resend asks first, then re-sends with the engine', (
    tester,
  ) async {
    items = [_item(OutboxStatus.unknownOutcome)];
    when(
      () => engine.resendUnknown('item-1'),
    ).thenAnswer((_) async => SyncResult.success);
    await open(tester);

    await tester.tap(find.text('Renvoyer'));
    await tester.pumpAndSettle();
    expect(find.text('Renvoyer cette action ?'), findsOneWidget);
    verifyNever(() => engine.resendUnknown(any()));

    await tester.tap(find.text('Renvoyer').last);
    await tester.pumpAndSettle();
    verify(() => engine.resendUnknown('item-1')).called(1);
  });
}
