import 'package:equatable/equatable.dart';

class CycleAttachmentData extends Equatable {
  final int id;
  final String url;
  final String? fileName;
  final String? mimeType;
  final DateTime? uploadedAt;

  const CycleAttachmentData({
    required this.id,
    required this.url,
    this.fileName,
    this.mimeType,
    this.uploadedAt,
  });

  factory CycleAttachmentData.fromJson(Map<String, dynamic> json) {
    return CycleAttachmentData(
      id: (json['id'] as num?)?.toInt() ?? 0,
      url: json['url']?.toString() ?? '',
      fileName: json['file_name']?.toString(),
      mimeType: json['mime_type']?.toString(),
      uploadedAt: DateTime.tryParse(json['uploaded_at']?.toString() ?? ''),
    );
  }

  @override
  List<Object?> get props => [id, url, fileName, mimeType, uploadedAt];
}
