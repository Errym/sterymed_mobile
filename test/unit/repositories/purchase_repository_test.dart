import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/cache/cache.dart';
import 'package:steriymed_mobile/core/errors/api_exception.dart';
import 'package:steriymed_mobile/core/storage/outbox/outbox_item.dart';
import 'package:steriymed_mobile/core/storage/outbox/outbox_operation.dart';
import 'package:steriymed_mobile/features/purchases/data/datasources/purchase_remote_datasource.dart';
import 'package:steriymed_mobile/features/purchases/data/models/goods_receipt_data.dart';
import 'package:steriymed_mobile/features/purchases/data/repositories/purchase_repository.dart';

import '../../mocks/mock_connectivity.dart';
import '../../mocks/mock_outbox_store.dart';
import '../../mocks/mock_sync_status_cubit.dart';

class MockPurchaseRemoteDatasource extends Mock
    implements PurchaseRemoteDatasource {}

void main() {
  late MockPurchaseRemoteDatasource remote;
  late MockOutboxStore outbox;
  late MockConnectivityService connectivity;
  late MockSyncStatusCubit syncStatus;
  late PurchaseRepository repo;

  const timeoutError = ApiException(
    code: 'timeout',
    message: 'timed out',
  );
  const validationError = ApiException(
    code: 'validation_error',
    message: 'bad qty',
    statusCode: 422,
  );
  final lines = [
    {'line_id': 'l1', 'qty_received': 5},
  ];

  setUpAll(() {
    registerFallbackValue(
      OutboxItem(
        id: 'fallback',
        operation: OutboxOperation.goodsReceipt,
        endpoint: '/x',
        method: 'POST',
        payload: const {},
        idempotencyKey: 'fallback-key',
        createdAt: DateTime(2026, 1, 1),
      ),
    );
  });

  setUp(() {
    remote = MockPurchaseRemoteDatasource();
    outbox = MockOutboxStore();
    connectivity = MockConnectivityService();
    syncStatus = MockSyncStatusCubit();
    repo = PurchaseRepository(
      remote,
      AppCache(),
      outbox: outbox,
      connectivity: connectivity,
      syncStatus: syncStatus,
    );

    when(() => outbox.enqueue(any())).thenAnswer((_) async {});
    when(() => syncStatus.refreshNow()).thenAnswer((_) async {});
  });

  test('online success returns the real remote result and never touches the outbox',
      () async {
    when(() => connectivity.isConnected).thenAnswer((_) async => true);
    when(() => remote.receive(
          poId: 'po-1',
          locationId: 'loc-1',
          lines: lines,
        )).thenAnswer((_) async => GoodsReceiptData(
          id: 'receipt-1',
          purchaseOrderId: 'po-1',
          totalLines: 1,
          receivedAt: DateTime(2026, 1, 1),
        ));

    final result =
        await repo.receive(poId: 'po-1', locationId: 'loc-1', lines: lines);

    expect(result.id, 'receipt-1');
    verifyNever(() => outbox.enqueue(any()));
    verifyNever(() => syncStatus.refreshNow());
  });

  test('a timeout while online falls through to the outbox with a synthetic result',
      () async {
    when(() => connectivity.isConnected).thenAnswer((_) async => true);
    when(() => remote.receive(
          poId: 'po-1',
          locationId: 'loc-1',
          lines: lines,
        )).thenThrow(timeoutError);

    final result =
        await repo.receive(poId: 'po-1', locationId: 'loc-1', lines: lines);

    expect(result.purchaseOrderId, 'po-1');
    expect(result.totalLines, 1);
    final captured =
        verify(() => outbox.enqueue(captureAny())).captured.single
            as OutboxItem;
    expect(captured.operation, OutboxOperation.goodsReceipt);
    expect(captured.endpoint, '/v1/purchase-orders/po-1/receipts');
    expect(captured.payload['location_id'], 'loc-1');
    verify(() => syncStatus.refreshNow()).called(1);
  });

  test('being offline enqueues directly without calling the remote datasource',
      () async {
    when(() => connectivity.isConnected).thenAnswer((_) async => false);

    final result =
        await repo.receive(poId: 'po-1', locationId: 'loc-1', lines: lines);

    expect(result.purchaseOrderId, 'po-1');
    verifyNever(() => remote.receive(
          poId: any(named: 'poId'),
          locationId: any(named: 'locationId'),
          lines: any(named: 'lines'),
        ));
    verify(() => outbox.enqueue(any())).called(1);
    verify(() => syncStatus.refreshNow()).called(1);
  });

  test('a non-network ApiException is rethrown, not queued', () async {
    when(() => connectivity.isConnected).thenAnswer((_) async => true);
    when(() => remote.receive(
          poId: 'po-1',
          locationId: 'loc-1',
          lines: lines,
        )).thenThrow(validationError);

    await expectLater(
      () => repo.receive(poId: 'po-1', locationId: 'loc-1', lines: lines),
      throwsA(isA<ApiException>()),
    );
    verifyNever(() => outbox.enqueue(any()));
    verifyNever(() => syncStatus.refreshNow());
  });
}
