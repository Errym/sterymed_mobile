import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/api_exception.dart';
import '../../data/models/cycle_data.dart';
import '../../data/models/cycle_release_data.dart';
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
    on<ReleaseCycle>(_onRelease);
    on<ResetCycleTransition>(_onReset);
  }

  Future<void> _onStart(
    StartCycle event,
    Emitter<CycleTransitionState> emit,
  ) async {
    await _runCycleOp(emit, () => _repository.start(event.cycleId));
  }

  Future<void> _onComplete(
    CompleteCycle event,
    Emitter<CycleTransitionState> emit,
  ) async {
    await _runCycleOp(emit, () => _repository.complete(event.cycleId));
  }

  Future<void> _onSubmit(
    SubmitCycleForRelease event,
    Emitter<CycleTransitionState> emit,
  ) async {
    await _runCycleOp(
      emit,
      () => _repository.submitForRelease(event.cycleId),
    );
  }

  Future<void> _onRelease(
    ReleaseCycle event,
    Emitter<CycleTransitionState> emit,
  ) async {
    emit(const CycleTransitionState(status: CycleTransitionStatus.loading));
    try {
      final release = await _repository.release(
        event.cycleId,
        decision: event.decision,
        reason: event.reason,
      );
      emit(CycleTransitionState(
        status: CycleTransitionStatus.success,
        release: release,
      ));
    } on ApiException catch (e) {
      emit(CycleTransitionState(
        status: CycleTransitionStatus.failure,
        error: e.message,
        errorCode: e.code,
      ));
    } catch (e) {
      emit(CycleTransitionState(
        status: CycleTransitionStatus.failure,
        error: e.toString(),
      ));
    }
  }

  Future<void> _runCycleOp(
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
        errorCode: e.code,
      ));
    } catch (e) {
      emit(CycleTransitionState(
        status: CycleTransitionStatus.failure,
        error: e.toString(),
      ));
    }
  }

  void _onReset(
    ResetCycleTransition event,
    Emitter<CycleTransitionState> emit,
  ) {
    emit(const CycleTransitionState());
  }
}
