import 'package:equatable/equatable.dart';
import '../../../../core/utils/server_time.dart';

class ProstheticCaseStatusHistoryData extends Equatable {
  final String id;
  final String? fromStatus;
  final String toStatus;
  final String? note;
  final String changedByUserId;
  final String changedByName;
  final DateTime createdAt;

  const ProstheticCaseStatusHistoryData({
    required this.id,
    this.fromStatus,
    required this.toStatus,
    this.note,
    required this.changedByUserId,
    required this.changedByName,
    required this.createdAt,
  });

  factory ProstheticCaseStatusHistoryData.fromJson(
    Map<String, dynamic> json,
  ) =>
      ProstheticCaseStatusHistoryData(
        id: json['id']?.toString() ?? '',
        fromStatus: json['from_status']?.toString(),
        toStatus: json['to_status']?.toString() ?? '',
        note: json['note']?.toString(),
        changedByUserId: json['changed_by_user_id']?.toString() ?? '',
        changedByName: json['changed_by_name']?.toString() ?? '',
        createdAt: parseServerTime(json['created_at']?.toString() ?? '') ??
            DateTime.now(),
      );

  @override
  List<Object?> get props => [id, toStatus, createdAt];
}
