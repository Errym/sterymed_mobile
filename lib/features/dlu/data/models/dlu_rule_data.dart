import 'package:equatable/equatable.dart';
import '../../../../core/utils/server_time.dart';

class DluRuleData extends Equatable {
  final String id;
  final String packagingType;
  final String storageCondition;
  final int shelfLifeDays;
  final DateTime? lastUpdatedAt;
  final String? lastUpdatedBy;
  final String? lastReason;
  final int existingLabelsCount;

  const DluRuleData({
    required this.id,
    required this.packagingType,
    required this.storageCondition,
    required this.shelfLifeDays,
    this.lastUpdatedAt,
    this.lastUpdatedBy,
    this.lastReason,
    this.existingLabelsCount = 0,
  });

  factory DluRuleData.fromJson(Map<String, dynamic> json) => DluRuleData(
        id: json['id']?.toString() ?? '',
        packagingType: json['packaging_type']?.toString() ?? '',
        storageCondition: json['storage_condition']?.toString() ?? '',
        shelfLifeDays: (json['shelf_life_days'] as num?)?.toInt() ?? 0,
        lastUpdatedAt:
            parseServerTime(json['last_updated_at']?.toString() ?? ''),
        lastUpdatedBy: json['last_updated_by']?.toString(),
        lastReason: json['last_reason']?.toString(),
        existingLabelsCount:
            (json['existing_labels_count'] as num?)?.toInt() ?? 0,
      );

  @override
  List<Object?> get props => [id, packagingType, storageCondition];
}
