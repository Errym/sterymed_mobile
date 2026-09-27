import 'package:equatable/equatable.dart';

class SupplierProductData extends Equatable {
  final String id;
  final String supplierId;
  final String productId;
  final String? supplierReference;
  final int packSize;
  final double? price;

  const SupplierProductData({
    required this.id,
    required this.supplierId,
    required this.productId,
    this.supplierReference,
    required this.packSize,
    this.price,
  });

  factory SupplierProductData.fromJson(Map<String, dynamic> json) =>
      SupplierProductData(
        id: json['id']?.toString() ?? '',
        supplierId: json['supplier_id']?.toString() ?? '',
        productId: json['product_id']?.toString() ?? '',
        supplierReference: json['supplier_reference']?.toString(),
        packSize: (json['pack_size'] as num?)?.toInt() ?? 1,
        price: double.tryParse(json['price']?.toString() ?? ''),
      );

  @override
  List<Object?> get props => [id, supplierId, productId];
}
