import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/api_exception.dart';
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
    try {
      final results = await Future.wait<Object>([
        _repository.show(event.cycleId),
        _repository.listItems(event.cycleId),
        _repository.listControlTests(event.cycleId),
        _repository.listAttachments(event.cycleId),
      ]);

      emit(state.copyWith(
        status: CycleDetailStatus.success,
        cycle: results[0] as CycleData,
        items: results[1] as List<CycleItemData>,
        controlTests: results[2] as List<ControlTestData>,
        attachments: results[3] as List<CycleAttachmentData>,
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(
        status: CycleDetailStatus.failure,
        error: e.message,
      ));
    }
  }

  Future<void> _onRefresh(
    RefreshCycleDetail event,
    Emitter<CycleDetailState> emit,
  ) async {
    add(LoadCycleDetail(event.cycleId));
  }
}
