import 'package:equatable/equatable.dart';

class PatientData extends Equatable {
  final String id;
  final String firstName;
  final String lastName;
  final String? reference;
  final DateTime? birthDate;
  final String? phone;
  final String? email;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PatientData({
    required this.id,
    this.firstName = '',
    this.lastName = '',
    this.reference,
    this.birthDate,
    this.phone,
    this.email,
    this.createdAt,
    this.updatedAt,
  });

  factory PatientData.fromJson(Map<String, dynamic> json) {
    // Field name candidates — the backend hasn't always returned the same
    // shape, so we try several keys before giving up.
    String? pick(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v != null && v.toString().trim().isNotEmpty) {
          return v.toString().trim();
        }
      }
      return null;
    }

    var first = pick(['first_name', 'firstName', 'given_name']) ?? '';
    var last = pick(['last_name', 'lastName', 'family_name', 'surname']) ?? '';

    // Fallback: split full_name / name
    if (first.isEmpty && last.isEmpty) {
      final full = pick(['full_name', 'name', 'display_name']) ?? '';
      if (full.isNotEmpty) {
        final parts = full.split(RegExp(r'\s+'));
        if (parts.length == 1) {
          first = parts.first;
        } else {
          first = parts.first;
          last = parts.sublist(1).join(' ');
        }
      }
    }

    return PatientData(
      id: pick(['id', 'uuid']) ?? '',
      firstName: first,
      lastName: last,
      reference: pick(['reference', 'file_number', 'dossier_ref']),
      birthDate: _parseDate(pick(['birth_date', 'birthdate', 'date_of_birth'])),
      phone: pick(['phone', 'phone_number', 'mobile', 'telephone']),
      email: pick(['email', 'email_address']),
      createdAt: _parseDate(pick(['created_at'])),
      updatedAt: _parseDate(pick(['updated_at'])),
    );
  }

  static DateTime? _parseDate(String? s) {
    if (s == null || s.isEmpty) return null;
    return DateTime.tryParse(s);
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

  PatientData copyWith({
    String? firstName,
    String? lastName,
    String? reference,
    String? phone,
    String? email,
  }) {
    return PatientData(
      id: id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      reference: reference ?? this.reference,
      birthDate: birthDate,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  List<Object?> get props =>
      [id, firstName, lastName, reference, phone, email];
}
