import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/utils/error_message.dart';
import '../../data/models/control_test_data.dart';
import '../../data/models/cycle_attachment_data.dart';
import '../../data/models/cycle_data.dart';
import '../../data/models/cycle_item_data.dart';
import '../../data/models/cycle_release_data.dart';
import '../../data/repositories/cycle_repository.dart';

part 'cycle_detail_event.dart';
part 'cycle_detail_state.dart';

class CycleDetailBloc extends Bloc<CycleDetailEvent, CycleDetailState> {
  final CycleRepository _repository;

  CycleDetailBloc(this._repository) : super(const CycleDetailState()) {
    on<LoadCycleDetail>(_onLoad);
    on<RefreshCycleDetail>(_onRefresh);
  }

  Future<void> _onLoad(
    LoadCycleDetail event,
    Emitter<CycleDetailState> emit,
  ) async {
    emit(state.copyWith(status: CycleDetailStatus.loading, error: null));

    // ── 1. Cycle itself — this MUST succeed ──
    CycleData? cycle;
    try {
      cycle = await _repository.show(event.cycleId);
    } on ApiException catch (e) {
      emit(state.copyWith(
        status: CycleDetailStatus.failure,
        error: ErrorMessage.from(e),
      ));
      return;
    } catch (e) {
      emit(state.copyWith(
        status: CycleDetailStatus.failure,
        error: ErrorMessage.from(e),
      ));
      return;
    }

    // Emit the cycle right away so the UI can render immediately.
    emit(state.copyWith(
      status: CycleDetailStatus.success,
      cycle: cycle,
    ));

    // ── 2. Auxiliary data — failures here don't block the screen ──
    var items = state.items;
    var controlTests = state.controlTests;
    var attachments = state.attachments;
    String? auxiliaryError;

    try {
      items = await _repository.listItems(event.cycleId);
    } catch (e) {
      auxiliaryError = 'Instruments : ${ErrorMessage.from(e)}';
    }

    try {
      controlTests = await _repository.listControlTests(event.cycleId);
    } catch (e) {
      auxiliaryError ??= 'Contrôles : ${ErrorMessage.from(e)}';
    }

    try {
      attachments = await _repository.listAttachments(event.cycleId);
    } catch (e) {
      auxiliaryError ??= 'Pièces jointes : ${ErrorMessage.from(e)}';
    }

    emit(state.copyWith(
      status: CycleDetailStatus.success,
      cycle: cycle,
      items: items,
      controlTests: controlTests,
      attachments: attachments,
      error: auxiliaryError,
    ));
  }

  Future<void> _onRefresh(
    RefreshCycleDetail event,
    Emitter<CycleDetailState> emit,
  ) async {
    add(LoadCycleDetail(event.cycleId));
  }
}
