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

  /// Two letters for the mark next to a reference: "PAT-000042" -> "PA".
  /// A reference with no letters falls back to its first digit.
  String get initials {
    final letters = reference.replaceAll(RegExp(r'[^A-Za-zÀ-ÿ]'), '');
    if (letters.isNotEmpty) {
      return letters.substring(0, letters.length >= 2 ? 2 : 1).toUpperCase();
    }
    final digits = reference.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.isNotEmpty ? digits.substring(0, 1) : '?';
  }

  @override
  List<Object?> get props => [id, reference];
}
