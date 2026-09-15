import 'package:dio/dio.dart';
import '../../config/app_config.dart';
import '../../errors/api_exception.dart';
import 'outbox_item.dart';
import 'outbox_status.dart';
import 'outbox_store.dart';
import 'sync_result.dart';

class SyncEngine {
  final OutboxStore _store;
  final Dio _dio;

  SyncEngine(this._store, this._dio);

  /// Attempt to flush all pending items in order.
  /// Returns the number of items successfully synced.
  Future<int> flush() async {
    final pending = _store.pending();
    int synced = 0;

    for (final item in pending) {
      final result = await _syncOne(item);
      if (result == SyncResult.success || result == SyncResult.conflict) {
        synced++;
      }
    }
    return synced;
  }

  Future<SyncResult> _syncOne(OutboxItem item) async {
    await _store.update(item.copyWith(status: OutboxStatus.syncing));

    try {
      await _dio.request(
        item.endpoint,
        data: item.payload,
        options: Options(
          method: item.method,
          headers: {'Idempotency-Key': item.idempotencyKey},
        ),
      );

      await _store.update(item.copyWith(status: OutboxStatus.synced));
      await _store.remove(item.id);
      return SyncResult.success;
    } on DioException catch (e) {
      final api = e.error;

      if (api is ApiException && api.statusCode == 409) {
        // Already recorded — treat as success
        await _store.update(item.copyWith(status: OutboxStatus.synced));
        await _store.remove(item.id);
        return SyncResult.conflict;
      }

      final nextRetry = item.retryCount + 1;
      if (nextRetry >= AppConfig.maxOutboxRetries) {
        await _store.update(
          item.copyWith(
            retryCount: nextRetry,
            status: OutboxStatus.manualReview,
            lastError: api is ApiException ? api.message : e.message,
          ),
        );
        return SyncResult.manualReview;
      }

      await _store.update(
        item.copyWith(
          retryCount: nextRetry,
          status: OutboxStatus.pending,
          lastError: api is ApiException ? api.message : e.message,
        ),
      );
      return SyncResult.error;
    } catch (e) {
      await _store.update(
        item.copyWith(
          retryCount: item.retryCount + 1,
          status: OutboxStatus.manualReview,
          lastError: e.toString(),
        ),
      );
      return SyncResult.manualReview;
    }
  }
}