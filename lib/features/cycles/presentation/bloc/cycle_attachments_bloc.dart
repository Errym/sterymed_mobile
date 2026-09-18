import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/api_exception.dart';
import '../../data/models/cycle_attachment_data.dart';
import '../../data/repositories/cycle_repository.dart';

part 'cycle_attachments_event.dart';
part 'cycle_attachments_state.dart';

class CycleAttachmentsBloc
    extends Bloc<CycleAttachmentsEvent, CycleAttachmentsState> {
  final CycleRepository _repository;
  final String cycleId;

  CycleAttachmentsBloc(this._repository, this.cycleId)
      : super(const CycleAttachmentsState()) {
    on<LoadAttachments>(_onLoad);
    on<UploadAttachment>(_onUpload);
    on<DeleteAttachment>(_onDelete);
  }

  Future<void> _onLoad(
    LoadAttachments event,
    Emitter<CycleAttachmentsState> emit,
  ) async {
    emit(state.copyWith(
      status: AttachmentsStatus.loading,
      error: null,
    ));
    try {
      final list = await _repository.listAttachments(cycleId);
      emit(CycleAttachmentsState(
        status: AttachmentsStatus.success,
        attachments: list,
      ));
    } on ApiException catch (e) {
      emit(CycleAttachmentsState(
        status: AttachmentsStatus.failure,
        error: e.message,
      ));
    }
  }

  Future<void> _onUpload(
    UploadAttachment event,
    Emitter<CycleAttachmentsState> emit,
  ) async {
    try {
      await _repository.uploadAttachment(
        cycleId,
        event.filePath,
        event.fileName,
      );
      add(const LoadAttachments());
    } on ApiException catch (e) {
      emit(state.copyWith(error: e.message));
    }
  }

  Future<void> _onDelete(
    DeleteAttachment event,
    Emitter<CycleAttachmentsState> emit,
  ) async {
    try {
      await _repository.deleteAttachment(cycleId, event.mediaId);
      add(const LoadAttachments());
    } on ApiException catch (e) {
      emit(state.copyWith(error: e.message));
    }
  }
}
