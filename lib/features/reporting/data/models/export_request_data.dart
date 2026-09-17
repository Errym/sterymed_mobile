import 'package:equatable/equatable.dart';

class ExportRequestData extends Equatable {
  final String id;
  final String reference;
  final String status;
  final int? sizeBytes;
  final DateTime requestedAt;
  final DateTime? expiresAt;
  final String? downloadUrl;

  const ExportRequestData({
    required this.id,
    required this.reference,
    required this.status,
    this.sizeBytes,
    required this.requestedAt,
    this.expiresAt,
    this.downloadUrl,
  });

  bool get isAvailable => status == 'available' && downloadUrl != null;
  bool get isExpired => status == 'expired';
  bool get isPending => status == 'pending' || status == 'processing';

  factory ExportRequestData.fromJson(Map<String, dynamic> json) =>
      ExportRequestData(
        id: json['id']?.toString() ?? '',
        reference: json['reference']?.toString() ?? '',
        status: json['status']?.toString() ?? 'pending',
        sizeBytes: (json['size_bytes'] as num?)?.toInt(),
        requestedAt:
            DateTime.tryParse(json['requested_at']?.toString() ?? '') ??
                DateTime.now(),
        expiresAt: DateTime.tryParse(json['expires_at']?.toString() ?? ''),
        downloadUrl: json['download_url']?.toString(),
      );

  @override
  List<Object?> get props => [id, status];
}
