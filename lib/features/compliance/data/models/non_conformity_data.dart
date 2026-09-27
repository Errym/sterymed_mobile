import 'package:equatable/equatable.dart';

class NonConformityData extends Equatable {
  final String id;
  final String subjectType;
  final String subjectId;
  final String description;
  final String raisedByUserId;
  final String? raisedByName;
  final DateTime raisedAt;
  final String? resolvedByUserId;
  final String? resolvedByName;
  final DateTime? resolvedAt;
  final String? resolution;

  const NonConformityData({
    required this.id,
    required this.subjectType,
    required this.subjectId,
    required this.description,
    required this.raisedByUserId,
    this.raisedByName,
    required this.raisedAt,
    this.resolvedByUserId,
    this.resolvedByName,
    this.resolvedAt,
    this.resolution,
  });

  bool get isOpen => resolvedAt == null;

  String get subjectTypeLabel =>
      subjectType == 'Cycle' ? 'Cycle' : 'Étiquette';

  factory NonConformityData.fromJson(Map<String, dynamic> json) =>
      NonConformityData(
        id: json['id']?.toString() ?? '',
        subjectType: json['subject_type']?.toString() ?? '',
        subjectId: json['subject_id']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        raisedByUserId: json['raised_by_user_id']?.toString() ?? '',
        raisedByName: json['raised_by_name']?.toString(),
        raisedAt: DateTime.tryParse(json['raised_at']?.toString() ?? '') ??
            DateTime.now(),
        resolvedByUserId: json['resolved_by_user_id']?.toString(),
        resolvedByName: json['resolved_by_name']?.toString(),
        resolvedAt: DateTime.tryParse(json['resolved_at']?.toString() ?? ''),
        resolution: json['resolution']?.toString(),
      );

  @override
  List<Object?> get props => [id, subjectType, subjectId, resolvedAt];
}
