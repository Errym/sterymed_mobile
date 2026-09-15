import 'package:equatable/equatable.dart';

class CycleItemData extends Equatable {
  final String id;
  final String cycleId;
  final String description;
  final String? batchId;
  final String? batchNumber;
  final DateTime createdAt;

  const CycleItemData({
    required this.id,
    required this.cycleId,
    required this.description,
    this.batchId,
    this.batchNumber,
    required this.createdAt,
  });

  factory CycleItemData.fromJson(Map<String, dynamic> json) {
    return CycleItemData(
      id: json['id']?.toString() ?? '',
      cycleId: json['cycle_id']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      batchId: json['batch_id']?.toString(),
      batchNumber: json['batch_number']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  @override
  List<Object?> get props =>
      [id, cycleId, description, batchId, batchNumber, createdAt];
}
