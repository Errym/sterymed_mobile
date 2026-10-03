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
      emit(
        state.copyWith(
          status: CycleDetailStatus.failure,
          error: ErrorMessage.from(e),
        ),
      );
      return;
    } catch (e) {
      emit(
        state.copyWith(
          status: CycleDetailStatus.failure,
          error: ErrorMessage.from(e),
        ),
      );
      return;
    }

    // Emit the cycle right away so the UI can render immediately.
    emit(state.copyWith(status: CycleDetailStatus.success, cycle: cycle));

    // ── 2. Auxiliary data — failures here don't block the screen, but each
    // one is remembered per section so it is never shown as "nothing there".
    var items = state.items;
    var controlTests = state.controlTests;
    var attachments = state.attachments;
    var release = state.release;
    String? itemsError;
    String? controlTestsError;
    String? attachmentsError;
    String? releaseError;
    String? auxiliaryError;

    try {
      items = await _repository.listItems(event.cycleId);
    } catch (e) {
      itemsError = ErrorMessage.from(e);
      auxiliaryError = 'Instruments : $itemsError';
    }

    try {
      controlTests = await _repository.listControlTests(event.cycleId);
    } catch (e) {
      controlTestsError = ErrorMessage.from(e);
      auxiliaryError ??= 'Contrôles : $controlTestsError';
    }

    try {
      attachments = await _repository.listAttachments(event.cycleId);
    } catch (e) {
      attachmentsError = ErrorMessage.from(e);
      auxiliaryError ??= 'Pièces jointes : $attachmentsError';
    }

    // A decision exists only once the cycle is released or rejected; before
    // that there is nothing to load (and nothing to be "missing").
    if (cycle.status == 'released' || cycle.status == 'rejected') {
      try {
        release = await _repository.getRelease(event.cycleId);
      } catch (e) {
        releaseError = ErrorMessage.from(e);
        auxiliaryError ??= 'Libération : $releaseError';
      }
    } else {
      release = null;
    }

    emit(
      state.copyWith(
        status: CycleDetailStatus.success,
        cycle: cycle,
        items: items,
        controlTests: controlTests,
        attachments: attachments,
        release: release,
        error: auxiliaryError,
        itemsError: itemsError,
        controlTestsError: controlTestsError,
        attachmentsError: attachmentsError,
        releaseError: releaseError,
        clearSectionErrors: true,
      ),
    );
  }

  Future<void> _onRefresh(
    RefreshCycleDetail event,
    Emitter<CycleDetailState> emit,
  ) async {
    add(LoadCycleDetail(event.cycleId));
  }
}
