import 'package:equatable/equatable.dart';

class NonConformityData extends Equatable {
  final String id;
  final String reference;
  final String kind;
  final String status;
  final String title;
  final String description;
  final String? cycleNumber;
  final String? batchNumber;
  final int? sachetsAffected;
  final String? openedBy;
  final DateTime openedAt;
  final String? resolution;

  const NonConformityData({
    required this.id,
    required this.reference,
    required this.kind,
    required this.status,
    required this.title,
    required this.description,
    this.cycleNumber,
    this.batchNumber,
    this.sachetsAffected,
    this.openedBy,
    required this.openedAt,
    this.resolution,
  });

  bool get isOpen => status == 'open';

  factory NonConformityData.fromJson(Map<String, dynamic> json) =>
      NonConformityData(
        id: json['id']?.toString() ?? '',
        reference: json['reference']?.toString() ?? '',
        kind: json['kind']?.toString() ?? 'correction',
        status: json['status']?.toString() ?? 'open',
        title: json['title']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        cycleNumber: json['cycle_number']?.toString(),
        batchNumber: json['batch_number']?.toString(),
        sachetsAffected: (json['sachets_affected'] as num?)?.toInt(),
        openedBy: json['opened_by']?.toString(),
        openedAt: DateTime.tryParse(json['opened_at']?.toString() ?? '') ??
            DateTime.now(),
        resolution: json['resolution']?.toString(),
      );

  @override
  List<Object?> get props => [id, reference, status, kind, openedAt];
}
