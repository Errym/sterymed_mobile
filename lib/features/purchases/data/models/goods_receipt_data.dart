import 'package:equatable/equatable.dart';

class GoodsReceiptData extends Equatable {
  final String id;
  final String purchaseOrderId;
  final int totalLines;
  final DateTime receivedAt;

  /// True when queued via the offline outbox rather than confirmed by the
  /// server. Backend never sends `is_queued`; the repository sets it.
  final bool isQueued;

  const GoodsReceiptData({
    required this.id,
    required this.purchaseOrderId,
    required this.totalLines,
    required this.receivedAt,
    this.isQueued = false,
  });

  factory GoodsReceiptData.fromJson(Map<String, dynamic> json) =>
      GoodsReceiptData(
        id: json['id']?.toString() ?? '',
        purchaseOrderId: json['purchase_order_id']?.toString() ?? '',
        totalLines: (json['total_lines'] as num?)?.toInt() ?? 0,
        receivedAt:
            DateTime.tryParse(json['received_at']?.toString() ?? '') ??
                DateTime.now(),
        isQueued: json['is_queued'] as bool? ?? false,
      );

  @override
  List<Object?> get props => [id, purchaseOrderId, receivedAt, isQueued];
}
