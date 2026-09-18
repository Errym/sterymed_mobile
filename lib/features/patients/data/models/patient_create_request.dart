class PatientCreateRequest {
  final String firstName;
  final String lastName;
  final String? reference;
  final DateTime? birthDate;
  final String? phone;
  final String? email;

  const PatientCreateRequest({
    required this.firstName,
    required this.lastName,
    this.reference,
    this.birthDate,
    this.phone,
    this.email,
  });

  Map<String, dynamic> toJson() => {
        'first_name': firstName,
        'last_name': lastName,
        if (reference != null && reference!.trim().isNotEmpty)
          'reference': reference!.trim(),
        if (birthDate != null)
          'birth_date': birthDate!.toIso8601String().split('T').first,
        if (phone != null && phone!.trim().isNotEmpty) 'phone': phone!.trim(),
        if (email != null && email!.trim().isNotEmpty) 'email': email!.trim(),
      };
}
