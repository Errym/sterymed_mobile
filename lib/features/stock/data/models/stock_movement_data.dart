import 'package:equatable/equatable.dart';

class StockMovementData extends Equatable {
  final String id;
  final String kind;
  final String batchId;
  final String locationId;
  final int qty;
  final String? reason;
  final DateTime createdAt;

  const StockMovementData({
    required this.id,
    required this.kind,
    required this.batchId,
    required this.locationId,
    required this.qty,
    this.reason,
    required this.createdAt,
  });

  factory StockMovementData.fromJson(Map<String, dynamic> json) =>
      StockMovementData(
        id: json['id']?.toString() ?? '',
        kind: json['kind']?.toString() ?? '',
        batchId: json['batch_id']?.toString() ?? '',
        locationId: json['location_id']?.toString() ?? '',
        qty: (json['qty'] as num?)?.toInt() ?? 0,
        reason: json['reason']?.toString(),
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
            DateTime.now(),
      );

  @override
  List<Object?> get props => [id, kind, batchId, locationId, qty, createdAt];
}
