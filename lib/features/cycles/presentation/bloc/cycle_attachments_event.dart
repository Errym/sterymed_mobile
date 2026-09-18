part of 'cycle_attachments_bloc.dart';

abstract class CycleAttachmentsEvent extends Equatable {
  const CycleAttachmentsEvent();
  @override
  List<Object?> get props => [];
}

class LoadAttachments extends CycleAttachmentsEvent {
  const LoadAttachments();
}

class UploadAttachment extends CycleAttachmentsEvent {
  final String fileName;
  final Uint8List bytes;
  final String? mimeType;

  const UploadAttachment({
    required this.fileName,
    required this.bytes,
    this.mimeType,
  });

  @override
  List<Object?> get props => [fileName, mimeType];
}

class DeleteAttachment extends CycleAttachmentsEvent {
  /// UUID string — matches what the backend returns and expects.
  final String attachmentId;
  const DeleteAttachment(this.attachmentId);
  @override
  List<Object?> get props => [attachmentId];
}
