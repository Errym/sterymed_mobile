import 'package:equatable/equatable.dart';

class PurchaseOrderLineData extends Equatable {
  final String id;
  final String productId;
  final String productName;
  final int qtyOrdered;
  final int qtyReceived;
  final double? unitPrice;

  const PurchaseOrderLineData({
    required this.id,
    required this.productId,
    required this.productName,
    required this.qtyOrdered,
    required this.qtyReceived,
    this.unitPrice,
  });

  int get qtyRemaining => (qtyOrdered - qtyReceived).clamp(0, qtyOrdered);

  /// Parses `unit_price` from either a JSON number OR a decimal string
  /// like "11.00". The backend returns decimals as strings.
  static double? _parsePrice(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw);
    return null;
  }

  factory PurchaseOrderLineData.fromJson(Map<String, dynamic> json) =>
      PurchaseOrderLineData(
        id: json['id']?.toString() ?? '',
        productId: json['product_id']?.toString() ?? '',
        productName: json['product_name']?.toString() ?? '',
        qtyOrdered: (json['qty_ordered'] as num?)?.toInt() ?? 0,
        qtyReceived: (json['qty_received'] as num?)?.toInt() ?? 0,
        unitPrice: _parsePrice(json['unit_price']),
      );

  @override
  List<Object?> get props => [id, productId, qtyOrdered, qtyReceived];
}
