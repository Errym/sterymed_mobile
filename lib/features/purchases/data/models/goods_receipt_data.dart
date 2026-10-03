import 'package:equatable/equatable.dart';

/// One line of a delivery as the server recorded it: the product, the
/// manufacturer lot and its expiry date, and the quantity that came in.
class GoodsReceiptLineData extends Equatable {
  final String id;
  final String productId;
  final String productName;
  final String batchId;
  final String batchNumber;
  final DateTime? expiryDate;
  final int qty;
  final String? discrepancyReason;

  const GoodsReceiptLineData({
    required this.id,
    required this.productId,
    required this.productName,
    required this.batchId,
    required this.batchNumber,
    required this.qty,
    this.expiryDate,
    this.discrepancyReason,
  });

  factory GoodsReceiptLineData.fromJson(Map<String, dynamic> json) =>
      GoodsReceiptLineData(
        id: json['id']?.toString() ?? '',
        productId: json['product_id']?.toString() ?? '',
        productName: json['product_name']?.toString() ?? 'Produit',
        batchId: json['batch_id']?.toString() ?? '',
        batchNumber: json['batch_number']?.toString() ?? '',
        expiryDate: DateTime.tryParse(json['expiry_date']?.toString() ?? ''),
        qty: (json['qty'] as num?)?.toInt() ?? 0,
        discrepancyReason: json['discrepancy_reason']?.toString(),
      );

  @override
  List<Object?> get props => [id, batchId, qty];
}

class GoodsReceiptData extends Equatable {
  final String id;
  final String purchaseOrderId;
  final int totalLines;
  final DateTime receivedAt;
  final String? receivedByName;
  final String? locationId;
  final String? locationName;

  /// Delivery-note / receipt photos kept as proof. 0 means the proof is still
  /// missing, which the screens show as a task, never hide.
  final int attachmentsCount;
  final List<GoodsReceiptLineData> lines;

  /// True when queued via the offline outbox rather than confirmed by the
  /// server. Backend never sends `is_queued`; the repository sets it.
  final bool isQueued;

  const GoodsReceiptData({
    required this.id,
    required this.purchaseOrderId,
    required this.totalLines,
    required this.receivedAt,
    this.receivedByName,
    this.locationId,
    this.locationName,
    this.attachmentsCount = 0,
    this.lines = const [],
    this.isQueued = false,
  });

  bool get hasProof => attachmentsCount > 0;

  factory GoodsReceiptData.fromJson(Map<String, dynamic> json) {
    final linesJson = json['lines'];
    final lines = linesJson is List
        ? linesJson
              .whereType<Map>()
              .map(
                (e) => GoodsReceiptLineData.fromJson(e.cast<String, dynamic>()),
              )
              .toList()
        : <GoodsReceiptLineData>[];
    return GoodsReceiptData(
      id: json['id']?.toString() ?? '',
      purchaseOrderId: json['purchase_order_id']?.toString() ?? '',
      totalLines: lines.length,
      receivedAt:
          DateTime.tryParse(json['received_at']?.toString() ?? '') ??
          DateTime.now(),
      receivedByName: json['received_by_name']?.toString(),
      locationId: json['location_id']?.toString(),
      locationName: json['location_name']?.toString(),
      attachmentsCount: (json['attachments_count'] as num?)?.toInt() ?? 0,
      lines: lines,
      isQueued: json['is_queued'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [id, purchaseOrderId, receivedAt, isQueued];
}
