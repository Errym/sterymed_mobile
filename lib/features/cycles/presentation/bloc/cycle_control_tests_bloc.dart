import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/api_exception.dart';
import '../../data/models/control_test_data.dart';
import '../../data/repositories/cycle_repository.dart';

part 'cycle_control_tests_event.dart';
part 'cycle_control_tests_state.dart';

class CycleControlTestsBloc
    extends Bloc<CycleControlTestsEvent, CycleControlTestsState> {
  final CycleRepository _repository;
  final String cycleId;

  CycleControlTestsBloc(this._repository, this.cycleId)
      : super(const CycleControlTestsState()) {
    on<LoadControlTests>(_onLoad);
    on<AddControlTest>(_onAdd);
  }

  Future<void> _onLoad(
    LoadControlTests event,
    Emitter<CycleControlTestsState> emit,
  ) async {
    emit(state.copyWith(
      status: ControlTestsStatus.loading,
      error: null,
    ));
    try {
      final tests = await _repository.listControlTests(cycleId);
      emit(CycleControlTestsState(
        status: ControlTestsStatus.success,
        tests: tests,
      ));
    } on ApiException catch (e) {
      emit(CycleControlTestsState(
        status: ControlTestsStatus.failure,
        error: e.message,
      ));
    }
  }

  Future<void> _onAdd(
    AddControlTest event,
    Emitter<CycleControlTestsState> emit,
  ) async {
    try {
      await _repository.addControlTest(cycleId, event.payload);
      add(const LoadControlTests());
    } on ApiException catch (e) {
      emit(state.copyWith(error: e.message));
    }
  }
}
