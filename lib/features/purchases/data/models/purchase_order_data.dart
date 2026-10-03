import 'package:equatable/equatable.dart';

import 'purchase_order_line_data.dart';
import '../../../../core/utils/server_time.dart';

class PurchaseOrderData extends Equatable {
  final String id;
  final String supplierId;
  final String supplierName;
  final String status;
  final List<PurchaseOrderLineData> lines;
  final DateTime createdAt;
  final DateTime? orderedAt;
  final DateTime? expectedAt;

  const PurchaseOrderData({
    required this.id,
    required this.supplierId,
    required this.supplierName,
    required this.status,
    required this.lines,
    required this.createdAt,
    this.orderedAt,
    this.expectedAt,
  });

  /// The backend has no PO reference/number field at all — this is a
  /// short, stable, scannable stand-in derived from the id, not a real
  /// business reference.
  String get shortId =>
      'CMD-${id.length >= 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase()}';

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

  // Backend enum (App\Domain\Purchasing\Enums\PurchaseOrderStatus) uses
  // 'partially_received', not 'partial' — the old check never matched a
  // real PO, so a second/third partial receipt was silently impossible.
  bool get canReceive => status == 'ordered' || status == 'partially_received';
  bool get canCancel => status == 'draft' || status == 'ordered';
  bool get canOrder => status == 'draft';

  /// Only a draft is still a working copy; once ordered it is a commitment to
  /// the supplier and the way out is to cancel it.
  bool get canEdit => status == 'draft';

  /// Units still to come across every line.
  int get qtyRemaining => lines.fold(0, (sum, l) => sum + l.qtyRemaining);

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
      supplierId: json['supplier_id']?.toString() ?? '',
      supplierName: json['supplier_name']?.toString() ?? '',
      status: json['status']?.toString() ?? 'draft',
      lines: lines,
      createdAt: parseServerTime(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      orderedAt: parseServerTime(json['ordered_at']?.toString() ?? ''),
      expectedAt: parseServerTime(json['expected_at']?.toString() ?? ''),
    );
  }

  @override
  List<Object?> get props => [id, status, expectedAt, lines];
}
