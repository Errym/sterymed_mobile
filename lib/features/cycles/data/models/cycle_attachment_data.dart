import 'package:equatable/equatable.dart';

class CycleAttachmentData extends Equatable {
  /// UUID string returned by the backend — used as the ID in the DELETE
  /// endpoint `/v1/cycles/{cycle}/attachments/{id}`.
  final String id;

  /// Original filename as uploaded.
  final String? fileName;

  /// Mime type from the backend (image/png, image/jpeg, application/pdf…).
  final String? mimeType;

  /// File size in bytes.
  final int? size;

  /// Pre-signed URL. NOTE: this URL expires (~10 min). Do not cache it.
  final String url;

  final DateTime? createdAt;

  const CycleAttachmentData({
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

  bool get isPdf =>
      (mimeType ?? '') == 'application/pdf' ||
      (fileName ?? '').toLowerCase().endsWith('.pdf');

  factory CycleAttachmentData.fromJson(Map<String, dynamic> json) {
    // id is a UUID string. Tolerate numeric ids too, just in case.
    final rawId = json['id'];
    final id = rawId?.toString() ?? '';

    // size may be int, num, or string.
    int? parsedSize;
    final rawSize = json['size'];
    if (rawSize is num) {
      parsedSize = rawSize.toInt();
    } else if (rawSize is String) {
      parsedSize = int.tryParse(rawSize);
    }

    return CycleAttachmentData(
      id: id,
      url: json['url']?.toString() ??
          json['original_url']?.toString() ??
          '',
      fileName: json['file_name']?.toString() ?? json['name']?.toString(),
      mimeType: json['mime_type']?.toString(),
      size: parsedSize,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }

  @override
  List<Object?> get props => [id, url, fileName, mimeType, size];
}
