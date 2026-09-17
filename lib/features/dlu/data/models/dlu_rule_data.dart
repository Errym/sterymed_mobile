import 'package:equatable/equatable.dart';

class DluRuleData extends Equatable {
  final String id;
  final String packagingType;
  final String storageCondition;
  final int shelfLifeDays;
  final String? reason;

  const DluRuleData({
    required this.id,
    required this.packagingType,
    required this.storageCondition,
    required this.shelfLifeDays,
    this.reason,
  });

  factory DluRuleData.fromJson(Map<String, dynamic> json) => DluRuleData(
        id: json['id']?.toString() ?? '',
        packagingType: json['packaging_type']?.toString() ?? '',
        storageCondition: json['storage_condition']?.toString() ?? '',
        shelfLifeDays: (json['shelf_life_days'] as num?)?.toInt() ?? 0,
        reason: json['reason']?.toString(),
      );

  @override
  List<Object?> get props => [id, packagingType, storageCondition];
}
