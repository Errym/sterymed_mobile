import 'package:equatable/equatable.dart';

class StockLevelData extends Equatable {
  final String id;
  final String productId;
  final String productName;
  final String reference;
  final String unit;
  final String locationId;
  final String locationName;
  final int qty;
  final int minThreshold;
  final String? batchId;
  final String? batchNumber;
  final DateTime? expiryDate;
  final bool isLow;
  final bool isExpired;
  final bool isNearExpiry;

  const StockLevelData({
    required this.id,
    required this.productId,
    required this.productName,
    required this.reference,
    required this.unit,
    required this.locationId,
    required this.locationName,
    required this.qty,
    required this.minThreshold,
    this.batchId,
    this.batchNumber,
    this.expiryDate,
    this.isLow = false,
    this.isExpired = false,
    this.isNearExpiry = false,
  });

  factory StockLevelData.fromJson(Map<String, dynamic> json) {
    final qty = (json['qty'] as num?)?.toInt() ?? 0;
    final min = (json['min_threshold'] as num?)?.toInt() ?? 0;
    final expiresAt =
        DateTime.tryParse(json['expiry_date']?.toString() ?? '');
    bool expired = false;
    bool near = false;
    if (expiresAt != null) {
      final days = expiresAt.difference(DateTime.now()).inDays;
      expired = days < 0;
      near = !expired && days <= 30;
    }
    return StockLevelData(
      id: json['id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      productName: json['product_name']?.toString() ?? '',
      reference: json['reference']?.toString() ?? '',
      unit: json['unit']?.toString() ?? 'u',
      locationId: json['location_id']?.toString() ?? '',
      locationName: json['location_name']?.toString() ?? '',
      qty: qty,
      minThreshold: min,
      batchId: json['batch_id']?.toString(),
      batchNumber: json['batch_number']?.toString(),
      expiryDate: expiresAt,
      isLow: min > 0 && qty <= min,
      isExpired: expired,
      isNearExpiry: near,
    );
  }

  @override
  List<Object?> get props => [id, productId, locationId, batchId, qty];
}
