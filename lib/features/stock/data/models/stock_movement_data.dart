import 'package:equatable/equatable.dart';
import '../../../../core/utils/server_time.dart';

class StockMovementData extends Equatable {
  final String id;
  final String kind;
  final String batchId;
  final String locationId;
  final int qty;
  final String? reason;
  final DateTime createdAt;

  /// True when this result was produced by the offline outbox path (queued
  /// locally, not yet confirmed by the server) rather than a real server
  /// response. The backend never sends `is_queued`; the repository sets it.
  final bool isQueued;

  const StockMovementData({
    required this.id,
    required this.kind,
    required this.batchId,
    required this.locationId,
    required this.qty,
    this.reason,
    required this.createdAt,
    this.isQueued = false,
  });

  factory StockMovementData.fromJson(Map<String, dynamic> json) =>
      StockMovementData(
        id: json['id']?.toString() ?? '',
        kind: json['type']?.toString() ?? '',
        batchId: json['batch_id']?.toString() ?? '',
        locationId: json['location_id']?.toString() ?? '',
        qty: (json['qty'] as num?)?.toInt() ?? 0,
        reason: json['reason']?.toString(),
        createdAt:
            parseServerTime(json['occurred_at']?.toString() ?? '') ??
                DateTime.now(),
        isQueued: json['is_queued'] as bool? ?? false,
      );

  @override
  List<Object?> get props =>
      [id, kind, batchId, locationId, qty, createdAt, isQueued];
}
