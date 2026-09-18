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
  final String filePath;
  final String fileName;
  const UploadAttachment({
    required this.filePath,
    required this.fileName,
  });
  @override
  List<Object?> get props => [filePath, fileName];
}

class DeleteAttachment extends CycleAttachmentsEvent {
  final int mediaId;
  const DeleteAttachment(this.mediaId);
  @override
  List<Object?> get props => [mediaId];
}
