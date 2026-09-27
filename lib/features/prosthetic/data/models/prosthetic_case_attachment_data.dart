import 'package:equatable/equatable.dart';

class ProstheticCaseAttachmentData extends Equatable {
  final String id;
  final String? fileName;
  final String? mimeType;
  final int? size;
  final String url;
  final DateTime? createdAt;

  const ProstheticCaseAttachmentData({
    required this.id,
    required this.url,
    this.fileName,
    this.mimeType,
    this.size,
    this.createdAt,
  });

  bool get isImage =>
      (mimeType ?? '').startsWith('image/') ||
      (fileName ?? '').toLowerCase().endsWith('.png') ||
      (fileName ?? '').toLowerCase().endsWith('.jpg') ||
      (fileName ?? '').toLowerCase().endsWith('.jpeg');

  factory ProstheticCaseAttachmentData.fromJson(Map<String, dynamic> json) {
    final rawSize = json['size'];
    int? parsedSize;
    if (rawSize is num) {
      parsedSize = rawSize.toInt();
    } else if (rawSize is String) {
      parsedSize = int.tryParse(rawSize);
    }

    return ProstheticCaseAttachmentData(
      id: json['id']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      fileName: json['file_name']?.toString(),
      mimeType: json['mime_type']?.toString(),
      size: parsedSize,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }

  @override
  List<Object?> get props => [id, url];
}
