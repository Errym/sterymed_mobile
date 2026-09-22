import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/errors/api_exception.dart';
import 'package:steriymed_mobile/core/storage/outbox/outbox_item.dart';
import 'package:steriymed_mobile/core/storage/outbox/outbox_status.dart';
import 'package:steriymed_mobile/core/storage/outbox/sync_engine.dart';

import '../../fixtures/outbox_item_fixture.dart';
import '../../mocks/mock_dio.dart';
import '../../mocks/mock_outbox_store.dart';

void main() {
  late MockOutboxStore store;
  late MockDio dio;
  late SyncEngine engine;

  setUpAll(() {
    registerFallbackValue(buildOutboxItem());
  });

  setUp(() {
    store = MockOutboxStore();
    dio = MockDio();
    engine = SyncEngine(store, dio);
    when(() => store.update(any())).thenAnswer((_) async {});
  });

  test('a successful flush removes the item from the outbox', () async {
    final item = buildOutboxItem();
    when(() => store.pending()).thenReturn([item]);
    when(() => store.remove(item.id)).thenAnswer((_) async {});
    when(
      () => dio.request(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenAnswer((_) async => jsonResponse(data: <String, dynamic>{}));

    final synced = await engine.flush();

    expect(synced, 1);
    verify(() => store.remove(item.id)).called(1);
  });

  test(
    'a 409 (genuine idempotency-key reuse) keeps the item for manual '
    'review, not removed — a benign replay never reaches this branch, '
    'it returns the original 2xx status and hits the success path',
    () async {
      final item = buildOutboxItem();
      when(() => store.pending()).thenReturn([item]);
      when(
        () => dio.request(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: item.endpoint),
          error: const ApiException(
            code: 'IDEMPOTENCY_KEY_REUSED',
            message: 'This Idempotency-Key was already used with a different request.',
            statusCode: 409,
          ),
        ),
      );

      final synced = await engine.flush();

      expect(synced, 0);
      verifyNever(() => store.remove(item.id));
      final captured = verify(() => store.update(captureAny())).captured;
      expect(captured.last, isA<OutboxItem>());
      expect((captured.last as OutboxItem).status, OutboxStatus.manualReview);
    },
  );

  test('a 422 response keeps the item for manual review, not removed', () async {
    final item = buildOutboxItem();
    when(() => store.pending()).thenReturn([item]);
    when(
      () => dio.request(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: item.endpoint),
        error: const ApiException(
          code: 'validation_error',
          message: 'The given data was invalid.',
          statusCode: 422,
        ),
      ),
    );

    final synced = await engine.flush();

    expect(synced, 0);
    verifyNever(() => store.remove(item.id));
    final captured = verify(() => store.update(captureAny())).captured;
    expect(captured.last, isA<OutboxItem>());
    expect((captured.last as OutboxItem).status, OutboxStatus.manualReview);
  });
}
