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
    this.firstName = '',
    this.lastName = '',
    this.reference,
    this.birthDate,
    this.phone,
    this.email,
  });

  factory PatientData.fromJson(Map<String, dynamic> json) {
    var first = json['first_name']?.toString() ?? '';
    var last = json['last_name']?.toString() ?? '';

    if (first.isEmpty && last.isEmpty) {
      final full = (json['full_name'] ?? json['name'])?.toString() ?? '';
      if (full.isNotEmpty) {
        final parts = full.trim().split(RegExp(r'\s+'));
        if (parts.length == 1) {
          first = parts.first;
        } else {
          first = parts.first;
          last = parts.sublist(1).join(' ');
        }
      }
    }

    return PatientData(
      id: json['id']?.toString() ?? '',
      firstName: first,
      lastName: last,
      reference: json['reference']?.toString(),
      birthDate: DateTime.tryParse(json['birth_date']?.toString() ?? ''),
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
    );
  }

  String get fullName {
    final combined = '$firstName $lastName'.trim();
    return combined.isEmpty ? 'Patient sans nom' : combined;
  }

  String get initials {
    final f = firstName.isNotEmpty ? firstName[0] : '';
    final l = lastName.isNotEmpty ? lastName[0] : '';
    final result = '$f$l'.toUpperCase();
    return result.isEmpty ? '?' : result;
  }

  @override
  List<Object?> get props => [id, firstName, lastName, reference];
}
