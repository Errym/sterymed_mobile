import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/api_exception.dart';
import '../../data/models/cycle_data.dart';
import '../../data/repositories/cycle_repository.dart';

part 'cycle_transition_event.dart';
part 'cycle_transition_state.dart';

class CycleTransitionBloc
    extends Bloc<CycleTransitionEvent, CycleTransitionState> {
  final CycleRepository _repository;

  CycleTransitionBloc(this._repository) : super(const CycleTransitionState()) {
    on<StartCycle>(_onStart);
    on<CompleteCycle>(_onComplete);
    on<SubmitCycleForRelease>(_onSubmit);
  }

  Future<void> _onStart(
    StartCycle event,
    Emitter<CycleTransitionState> emit,
  ) async {
    await _run(emit, () => _repository.start(event.cycleId));
  }

  Future<void> _onComplete(
    CompleteCycle event,
    Emitter<CycleTransitionState> emit,
  ) async {
    await _run(emit, () => _repository.complete(event.cycleId));
  }

  Future<void> _onSubmit(
    SubmitCycleForRelease event,
    Emitter<CycleTransitionState> emit,
  ) async {
    await _run(emit, () => _repository.submitForRelease(event.cycleId));
  }

  Future<void> _run(
    Emitter<CycleTransitionState> emit,
    Future<CycleData> Function() op,
  ) async {
    emit(const CycleTransitionState(status: CycleTransitionStatus.loading));
    try {
      final cycle = await op();
      emit(CycleTransitionState(
        status: CycleTransitionStatus.success,
        cycle: cycle,
      ));
    } on ApiException catch (e) {
      emit(CycleTransitionState(
        status: CycleTransitionStatus.failure,
        error: e.message,
      ));
    }
  }
}
