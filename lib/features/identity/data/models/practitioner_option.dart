import 'package:equatable/equatable.dart';

/// Someone who may be named as the practitioner on a clinical record (an active
/// owner, admin or practitioner of this practice), as returned by
/// `GET /v1/practitioners`. Carries a name and role only, never contact data.
class PractitionerOption extends Equatable {
  final String id;
  final String name;
  final String? role;

  const PractitionerOption({required this.id, required this.name, this.role});

  factory PractitionerOption.fromJson(Map<String, dynamic> json) =>
      PractitionerOption(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        role: json['role']?.toString(),
      );

  @override
  List<Object?> get props => [id, name, role];
}
