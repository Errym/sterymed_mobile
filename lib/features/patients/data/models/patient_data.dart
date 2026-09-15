import 'package:equatable/equatable.dart';

class PatientData extends Equatable {
  final String id;
  final String firstName;
  final String lastName;
  final String? reference;
  final DateTime? birthDate;
  final String? phone;
  final String? email;

  const PatientData({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.reference,
    this.birthDate,
    this.phone,
    this.email,
  });

  String get fullName => '$firstName $lastName'.trim();

  String get initials {
    final f = firstName.isNotEmpty ? firstName[0] : '';
    final l = lastName.isNotEmpty ? lastName[0] : '';
    return '$f$l'.toUpperCase();
  }

  factory PatientData.fromJson(Map<String, dynamic> json) {
    return PatientData(
      id: json['id']?.toString() ?? '',
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      reference: json['reference']?.toString(),
      birthDate: DateTime.tryParse(json['birth_date']?.toString() ?? ''),
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
    );
  }

  @override
  List<Object?> get props =>
      [id, firstName, lastName, reference, birthDate, phone, email];
}