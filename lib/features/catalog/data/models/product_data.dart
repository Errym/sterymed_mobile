import 'package:equatable/equatable.dart';

class ProductData extends Equatable {
  final String id;
  final String name;
  final String reference;
  final String unit;
  final int minThreshold;
  final bool isSterilizable;
  final String? barcode;
  final String? categoryId;
  final String? defaultLocationId;

  const ProductData({
    required this.id,
    required this.name,
    required this.reference,
    required this.unit,
    required this.minThreshold,
    required this.isSterilizable,
    this.barcode,
    this.categoryId,
    this.defaultLocationId,
  });

  factory ProductData.fromJson(Map<String, dynamic> json) => ProductData(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        reference: json['reference']?.toString() ?? '',
        unit: json['unit']?.toString() ?? 'u',
        minThreshold: (json['min_threshold'] as num?)?.toInt() ?? 0,
        isSterilizable: json['is_sterilizable'] as bool? ?? false,
        barcode: json['barcode']?.toString(),
        categoryId: json['category_id']?.toString(),
        defaultLocationId: json['default_location_id']?.toString(),
      );

  @override
  List<Object?> get props => [id, reference];
}

class ProductCreateRequest {
  final String name;
  final String reference;
  final String unit;
  final int minThreshold;
  final bool isSterilizable;
  final String? barcode;
  final String? categoryId;
  final String? defaultLocationId;

  const ProductCreateRequest({
    required this.name,
    required this.reference,
    required this.unit,
    required this.minThreshold,
    required this.isSterilizable,
    this.barcode,
    this.categoryId,
    this.defaultLocationId,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'reference': reference,
        'unit': unit,
        'min_threshold': minThreshold,
        'is_sterilizable': isSterilizable,
        if (barcode != null) 'barcode': barcode,
        if (categoryId != null) 'category_id': categoryId,
        if (defaultLocationId != null) 'default_location_id': defaultLocationId,
      };
}
