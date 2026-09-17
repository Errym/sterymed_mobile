import 'package:equatable/equatable.dart';

class GoodsReceiptData extends Equatable {
  final String id;
  final String purchaseOrderId;
  final int totalLines;
  final DateTime receivedAt;

  const GoodsReceiptData({
    required this.id,
    required this.purchaseOrderId,
    required this.totalLines,
    required this.receivedAt,
  });

  factory GoodsReceiptData.fromJson(Map<String, dynamic> json) =>
      GoodsReceiptData(
        id: json['id']?.toString() ?? '',
        purchaseOrderId: json['purchase_order_id']?.toString() ?? '',
        totalLines: (json['total_lines'] as num?)?.toInt() ?? 0,
        receivedAt:
            DateTime.tryParse(json['received_at']?.toString() ?? '') ??
                DateTime.now(),
      );

  @override
  List<Object?> get props => [id, purchaseOrderId, receivedAt];
}
