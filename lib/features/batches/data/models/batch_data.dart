import 'package:equatable/equatable.dart';

class BatchData extends Equatable {
  final String id;
  final String productId;
  final String? productName;
  final String batchNumber;
  final String? expiryDate;
  final int? qty;

  const BatchData({
    required this.id,
    required this.productId,
    this.productName,
    required this.batchNumber,
    this.expiryDate,
    this.qty,
  });

  factory BatchData.fromJson(Map<String, dynamic> json) => BatchData(
        id: json['id']?.toString() ?? '',
        productId: json['product_id']?.toString() ?? '',
        productName: json['product_name']?.toString(),
        batchNumber: json['batch_number']?.toString() ?? '',
        expiryDate: json['expiry_date']?.toString(),
        qty: (json['qty'] as num?)?.toInt(),
      );

  @override
  List<Object?> get props => [id, batchNumber];
}
