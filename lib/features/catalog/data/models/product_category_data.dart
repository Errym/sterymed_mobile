import 'package:equatable/equatable.dart';

class ProductCategoryData extends Equatable {
  final String id;
  final String name;
  final String? parentCategoryId;

  const ProductCategoryData({
    required this.id,
    required this.name,
    this.parentCategoryId,
  });

  factory ProductCategoryData.fromJson(Map<String, dynamic> json) {
    return ProductCategoryData(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      parentCategoryId: json['parent_category_id']?.toString(),
    );
  }

  @override
  List<Object?> get props => [id, name, parentCategoryId];
}
