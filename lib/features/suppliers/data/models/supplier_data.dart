import 'package:equatable/equatable.dart';

class SupplierData extends Equatable {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? address;

  const SupplierData({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.address,
  });

  factory SupplierData.fromJson(Map<String, dynamic> json) => SupplierData(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        email: json['email']?.toString(),
        phone: json['phone']?.toString(),
        address: json['address']?.toString(),
      );

  @override
  List<Object?> get props => [id, name];
}
