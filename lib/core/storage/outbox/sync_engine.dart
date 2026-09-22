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

  /// Flush every pending item, in order, one at a time.
  /// Returns the number of items that succeeded.
  Future<int> flush() async {
    final pending = _store.pending();
    int synced = 0;

    for (final item in pending) {
      final result = await _syncOne(item);
      if (result == SyncResult.success) {
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

      await _store.remove(item.id);
      return SyncResult.success;
    } on DioException catch (e) {
      final api = e.error;

      // 409 / 422 / 403 → hard errors, keep for manual review.
      //
      // A benign idempotency replay (same key, same payload) never
      // reaches this branch — the backend replays the cached response
      // verbatim at its ORIGINAL status (e.g. 200), which the success
      // path above already handles correctly. A 409 here means the
      // Idempotency-Key was reused with a DIFFERENT payload — a genuine
      // anomaly (should never happen with our own UUID v4 keys) where
      // this item's data was NOT actually recorded under this key.
      // Silently discarding it would be silent data loss, so it gets
      // the same manual-review treatment as a real validation/permission
      // error, not an auto-remove.
      if (api is ApiException &&
          (api.statusCode == 409 ||
              api.statusCode == 422 ||
              api.statusCode == 403)) {
        await _store.update(
          item.copyWith(
            status: OutboxStatus.manualReview,
            lastError: api.message,
          ),
        );
        return SyncResult.manualReview;
      }

      // 5xx or network → retry with backoff.
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
          status: OutboxStatus.manualReview,
          lastError: e.toString(),
        ),
      );
      return SyncResult.manualReview;
    }
  }

  /// Manually retry one item (from the queue screen).
  Future<SyncResult> retryOne(String id) async {
    final item = _store.all().firstWhere((i) => i.id == id);
    return _syncOne(item);
  }
}