import 'package:equatable/equatable.dart';

import 'purchase_order_line_data.dart';

class PurchaseOrderData extends Equatable {
  final String id;
  final String reference;
  final String supplierId;
  final String supplierName;
  final String status;
  final List<PurchaseOrderLineData> lines;
  final DateTime createdAt;
  final DateTime? orderedAt;

  const PurchaseOrderData({
    required this.id,
    required this.reference,
    required this.supplierId,
    required this.supplierName,
    required this.status,
    required this.lines,
    required this.createdAt,
    this.orderedAt,
  });

  double? get totalAmount {
    double sum = 0;
    var hasPrice = false;
    for (final l in lines) {
      if (l.unitPrice != null) {
        sum += l.unitPrice! * l.qtyOrdered;
        hasPrice = true;
      }
    }
    return hasPrice ? sum : null;
  }

  bool get canReceive => status == 'ordered' || status == 'partial';
  bool get canCancel => status == 'draft' || status == 'ordered';
  bool get canOrder => status == 'draft';

  factory PurchaseOrderData.fromJson(Map<String, dynamic> json) {
    final linesJson = json['lines'];
    final lines = linesJson is List
        ? linesJson
            .whereType<Map>()
            .map((e) =>
                PurchaseOrderLineData.fromJson(e.cast<String, dynamic>()))
            .toList()
        : <PurchaseOrderLineData>[];

    return PurchaseOrderData(
      id: json['id']?.toString() ?? '',
      reference: json['reference']?.toString() ?? '',
      supplierId: json['supplier_id']?.toString() ?? '',
      supplierName: json['supplier_name']?.toString() ?? '',
      status: json['status']?.toString() ?? 'draft',
      lines: lines,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      orderedAt: DateTime.tryParse(json['ordered_at']?.toString() ?? ''),
    );
  }

  @override
  List<Object?> get props => [id, reference, status];
}
