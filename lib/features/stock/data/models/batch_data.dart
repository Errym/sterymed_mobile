import 'package:equatable/equatable.dart';

/// A lot, as `GET /v1/batches` returns it: where it came from, when it
/// arrived, whether it is usable, and how much of it is on hand across every
/// place.
class BatchData extends Equatable {
  final String id;
  final String productId;
  final String productName;
  final String? supplierId;
  final String supplierName;
  final String batchNumber;
  final DateTime? expiryDate;
  final DateTime? receivedAt;

  /// `active` or `quarantined` (the only two the server has).
  final String status;
  final int qtyOnHand;

  const BatchData({
    required this.id,
    required this.productId,
    required this.productName,
    required this.supplierName,
    required this.batchNumber,
    required this.status,
    required this.qtyOnHand,
    this.supplierId,
    this.expiryDate,
    this.receivedAt,
  });

  bool get isQuarantined => status == 'quarantined';

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Whole calendar days until expiry (negative once past); null without a DLC.
  /// A lot that expires today is still usable today.
  int? get daysToExpiry {
    final e = expiryDate;
    if (e == null) return null;
    return _day(e).difference(_day(DateTime.now())).inDays;
  }

  bool get isExpired => (daysToExpiry ?? 1) < 0;
  bool get isNearExpiry {
    final d = daysToExpiry;
    return d != null && d >= 0 && d <= 30;
  }

  /// Nothing left on any shelf.
  bool get isEmpty => qtyOnHand <= 0;

  factory BatchData.fromJson(Map<String, dynamic> json) => BatchData(
        id: json['id']?.toString() ?? '',
        productId: json['product_id']?.toString() ?? '',
        productName: json['product_name']?.toString() ?? '',
        supplierId: json['supplier_id']?.toString(),
        supplierName: json['supplier_name']?.toString() ?? '',
        batchNumber: json['batch_number']?.toString() ?? '',
        expiryDate: DateTime.tryParse(json['expiry_date']?.toString() ?? ''),
        receivedAt: DateTime.tryParse(json['received_at']?.toString() ?? '')
            ?.toLocal(),
        status: json['status']?.toString() ?? 'active',
        qtyOnHand: (json['qty_on_hand'] as num?)?.toInt() ?? 0,
      );

  @override
  List<Object?> get props => [
        id,
        productId,
        productName,
        supplierId,
        supplierName,
        batchNumber,
        expiryDate,
        receivedAt,
        status,
        qtyOnHand,
      ];
}
