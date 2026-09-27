import 'package:equatable/equatable.dart';

class LaboratoryData extends Equatable {
  final String id;
  final String name;
  final String? contactName;
  final String? contactPhone;
  final String? contactEmail;
  final String? address;
  final String? notes;
  final bool archived;

  const LaboratoryData({
    required this.id,
    required this.name,
    this.contactName,
    this.contactPhone,
    this.contactEmail,
    this.address,
    this.notes,
    this.archived = false,
  });

  factory LaboratoryData.fromJson(Map<String, dynamic> json) =>
      LaboratoryData(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        contactName: json['contact_name']?.toString(),
        contactPhone: json['contact_phone']?.toString(),
        contactEmail: json['contact_email']?.toString(),
        address: json['address']?.toString(),
        notes: json['notes']?.toString(),
        archived: json['archived'] as bool? ?? false,
      );

  @override
  List<Object?> get props => [id, name, archived];
}
