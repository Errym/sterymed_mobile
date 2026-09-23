import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/errors/api_exception.dart';
import 'package:steriymed_mobile/core/storage/outbox/outbox_item.dart';
import 'package:steriymed_mobile/core/storage/outbox/outbox_operation.dart';
import 'package:steriymed_mobile/features/labels/data/datasources/label_usage_remote_datasource.dart';
import 'package:steriymed_mobile/features/labels/data/models/label_usage_data.dart';
import 'package:steriymed_mobile/features/labels/data/repositories/label_usage_repository.dart';

import '../../mocks/mock_connectivity.dart';
import '../../mocks/mock_outbox_store.dart';
import '../../mocks/mock_sync_status_cubit.dart';

class MockLabelUsageRemoteDatasource extends Mock
    implements LabelUsageRemoteDatasource {}

void main() {
  late MockLabelUsageRemoteDatasource remote;
  late MockOutboxStore outbox;
  late MockConnectivityService connectivity;
  late MockSyncStatusCubit syncStatus;
  late LabelUsageRepository repo;

  const networkError = ApiException(
    code: 'network_error',
    message: 'no connection',
  );
  const forbiddenError = ApiException(
    code: 'forbidden',
    message: 'not allowed',
    statusCode: 403,
  );

  setUpAll(() {
    registerFallbackValue(
      OutboxItem(
        id: 'fallback',
        operation: OutboxOperation.labelUsage,
        endpoint: '/x',
        method: 'POST',
        payload: const {},
        idempotencyKey: 'fallback-key',
        createdAt: DateTime(2026, 1, 1),
      ),
    );
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    remote = MockLabelUsageRemoteDatasource();
    outbox = MockOutboxStore();
    connectivity = MockConnectivityService();
    syncStatus = MockSyncStatusCubit();
    repo = LabelUsageRepository(
      remote,
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
    when(() => remote.recordUsage(
          labelId: 'label-1',
          payload: any(named: 'payload'),
        )).thenAnswer((_) async => LabelUsageData(
          id: 'usage-1',
          labelId: 'label-1',
          patientId: 'p1',
          patientName: 'Marie Curie',
          practitionerId: 'pr1',
          practitionerName: 'Dr Dupont',
          procedure: 'Détartrage',
          usedAt: DateTime(2026, 1, 1),
        ));

    final result = await repo.recordUsage(
      labelId: 'label-1',
      patientId: 'p1',
      patientName: 'Marie Curie',
      practitionerId: 'pr1',
      practitionerName: 'Dr Dupont',
      procedure: 'Détartrage',
    );

    expect(result.id, 'usage-1');
    verifyNever(() => outbox.enqueue(any()));
    verifyNever(() => syncStatus.refreshNow());
  });

  test('a network ApiException while online falls through to the outbox with a synthetic result',
      () async {
    when(() => connectivity.isConnected).thenAnswer((_) async => true);
    when(() => remote.recordUsage(
          labelId: 'label-1',
          payload: any(named: 'payload'),
        )).thenThrow(networkError);

    final result = await repo.recordUsage(
      labelId: 'label-1',
      patientId: 'p1',
      patientName: 'Marie Curie',
      practitionerId: 'pr1',
      practitionerName: 'Dr Dupont',
      procedure: 'Détartrage',
      notes: 'RAS',
    );

    expect(result.patientName, 'Marie Curie');
    expect(result.procedure, 'Détartrage');
    final captured =
        verify(() => outbox.enqueue(captureAny())).captured.single
            as OutboxItem;
    expect(captured.operation, OutboxOperation.labelUsage);
    expect(captured.endpoint, '/v1/labels/label-1/usage');
    expect(captured.payload['patient_id'], 'p1');
    expect(captured.payload['notes'], 'RAS');
    verify(() => syncStatus.refreshNow()).called(1);
  });

  test('being offline enqueues directly without calling the remote datasource',
      () async {
    when(() => connectivity.isConnected).thenAnswer((_) async => false);

    final result = await repo.recordUsage(
      labelId: 'label-1',
      patientId: 'p1',
      patientName: 'Marie Curie',
      practitionerId: 'pr1',
      practitionerName: 'Dr Dupont',
      procedure: 'Détartrage',
    );

    expect(result.labelId, 'label-1');
    verifyNever(() => remote.recordUsage(
          labelId: any(named: 'labelId'),
          payload: any(named: 'payload'),
        ));
    verify(() => outbox.enqueue(any())).called(1);
    verify(() => syncStatus.refreshNow()).called(1);
  });

  test('a non-network ApiException (e.g. forbidden) is rethrown, not queued',
      () async {
    when(() => connectivity.isConnected).thenAnswer((_) async => true);
    when(() => remote.recordUsage(
          labelId: 'label-1',
          payload: any(named: 'payload'),
        )).thenThrow(forbiddenError);

    await expectLater(
      () => repo.recordUsage(
        labelId: 'label-1',
        patientId: 'p1',
        patientName: 'Marie Curie',
        practitionerId: 'pr1',
        practitionerName: 'Dr Dupont',
        procedure: 'Détartrage',
      ),
      throwsA(isA<ApiException>()),
    );
    verifyNever(() => outbox.enqueue(any()));
    verifyNever(() => syncStatus.refreshNow());
  });
}
