import 'package:equatable/equatable.dart';

/// Patients carry no PII by design — the backend's `Patient` model is
/// `{id, reference}` only, an auto-generated pseudonym (e.g. "PAT-000042").
/// `CreatePatientAction`'s own docblock: "there is nothing else to
/// capture... reference is generated here, never client-supplied, so it
/// can never accidentally carry real patient data typed into a free-text
/// field." See docs/BACKEND_BUGS.md#bug-008.
class PatientData extends Equatable {
  final String id;
  final String reference;

  const PatientData({required this.id, required this.reference});

  factory PatientData.fromJson(Map<String, dynamic> json) => PatientData(
        id: json['id']?.toString() ?? '',
        reference: json['reference']?.toString() ?? '',
      );

  String get initials {
    final digits = reference.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isNotEmpty) return digits.substring(0, 1);
    return reference.isNotEmpty ? reference[0].toUpperCase() : '?';
  }

  @override
  List<Object?> get props => [id, reference];
}
