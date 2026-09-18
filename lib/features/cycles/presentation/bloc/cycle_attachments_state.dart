part of 'cycle_attachments_bloc.dart';

enum AttachmentsStatus { initial, loading, success, failure }

class CycleAttachmentsState extends Equatable {
  final AttachmentsStatus status;
  final List<CycleAttachmentData> attachments;
  final String? error;

  const CycleAttachmentsState({
    this.status = AttachmentsStatus.initial,
    this.attachments = const [],
    this.error,
  });

  CycleAttachmentsState copyWith({
    AttachmentsStatus? status,
    List<CycleAttachmentData>? attachments,
    String? error,
  }) {
    return CycleAttachmentsState(
      status: status ?? this.status,
      attachments: attachments ?? this.attachments,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [status, attachments, error];
}
