import 'package:equatable/equatable.dart';
import '../../../../core/utils/server_time.dart';

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

  /// `active` or `quarantined`; a quarantined batch cannot leave the stock.
  final String batchStatus;

  /// An archived location can be emptied but takes no new stock.
  final bool locationArchived;

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
    this.batchStatus = 'active',
    this.locationArchived = false,
  });

  bool get isQuarantined => batchStatus == 'quarantined';

  /// Identifies the (batch, location) pair this row stands for.
  String get pairKey => '${batchId ?? ''}|$locationId';

  factory StockLevelData.fromJson(Map<String, dynamic> json) {
    final qty = (json['quantity'] as num?)?.toInt() ?? 0;
    final min = (json['min_threshold'] as num?)?.toInt() ?? 0;
    final expiresAt =
        parseServerTime(json['expiry_date']?.toString() ?? '');
    bool expired = false;
    bool near = false;
    if (expiresAt != null) {
      // Whole calendar days: a batch that expires today is still usable today.
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final expiryDay = DateTime(expiresAt.year, expiresAt.month, expiresAt.day);
      final days = expiryDay.difference(today).inDays;
      expired = days < 0;
      near = !expired && days <= 30;
    }
    return StockLevelData(
      id: json['id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      productName: json['product_name']?.toString() ?? '',
      reference: json['product_reference']?.toString() ?? '',
      unit: json['product_unit']?.toString() ?? 'u',
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
      batchStatus: json['batch_status']?.toString() ?? 'active',
      locationArchived: json['location_archived'] == true,
    );
  }

  @override
  List<Object?> get props => [
    id,
    productId,
    locationId,
    batchId,
    qty,
    batchStatus,
    locationArchived,
  ];
}
