import 'package:steriymed_mobile/core/storage/outbox/outbox_item.dart';
import 'package:steriymed_mobile/core/storage/outbox/outbox_operation.dart';
import 'package:steriymed_mobile/core/storage/outbox/outbox_status.dart';

OutboxItem buildOutboxItem({
  String id = 'outbox-1',
  OutboxOperation operation = OutboxOperation.stockIssue,
  OutboxStatus status = OutboxStatus.pending,
  int retryCount = 0,
}) {
  return OutboxItem(
    id: id,
    operation: operation,
    endpoint: '/v1/stock-movements/issue',
    method: 'POST',
    payload: const {'batch_id': 'b-1', 'location_id': 'l-1', 'qty': 1},
    idempotencyKey: 'key-$id',
    createdAt: DateTime(2026, 9, 18, 10, 0),
    status: status,
    retryCount: retryCount,
  );
}
