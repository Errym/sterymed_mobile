import 'package:equatable/equatable.dart';

class ExportRequestData extends Equatable {
  final String id;
  final String status;
  final String requestedByName;
  final DateTime requestedAt;
  final String? error;
  final DateTime? completedAt;
  final int? sizeBytes;
  final int? recordCount;
  final int? fileCount;
  final DateTime? expiresAt;

  const ExportRequestData({
    required this.id,
    required this.status,
    required this.requestedByName,
    required this.requestedAt,
    this.error,
    this.completedAt,
    this.sizeBytes,
    this.recordCount,
    this.fileCount,
    this.expiresAt,
  });

  bool get isCompleted => status == 'completed';
  bool get isExpired => status == 'expired';
  bool get isPending => status == 'pending' || status == 'processing';
  bool get isFailed => status == 'failed';

  factory ExportRequestData.fromJson(Map<String, dynamic> json) =>
      ExportRequestData(
        id: json['id']?.toString() ?? '',
        status: json['status']?.toString() ?? 'pending',
        requestedByName: json['requested_by_name']?.toString() ?? '',
        requestedAt:
            DateTime.tryParse(json['requested_at']?.toString() ?? '') ??
                DateTime.now(),
        error: json['error']?.toString(),
        completedAt: DateTime.tryParse(json['completed_at']?.toString() ?? ''),
        sizeBytes: (json['size_bytes'] as num?)?.toInt(),
        recordCount: (json['record_count'] as num?)?.toInt(),
        fileCount: (json['file_count'] as num?)?.toInt(),
        expiresAt: DateTime.tryParse(json['expires_at']?.toString() ?? ''),
      );

  @override
  List<Object?> get props => [id, status];
}
