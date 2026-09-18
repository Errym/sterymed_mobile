import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/api_exception.dart';
import '../../data/models/cycle_release_data.dart';
import '../../data/repositories/cycle_repository.dart';

part 'cycle_release_event.dart';
part 'cycle_release_state.dart';

class CycleReleaseBloc extends Bloc<CycleReleaseEvent, CycleReleaseState> {
  final CycleRepository _repository;

  CycleReleaseBloc(this._repository) : super(const CycleReleaseState()) {
    on<SubmitCycleRelease>(_onSubmit);
  }

  Future<void> _onSubmit(
    SubmitCycleRelease event,
    Emitter<CycleReleaseState> emit,
  ) async {
    emit(state.copyWith(status: CycleReleaseStatus.loading, error: null));
    try {
      final release = await _repository.release(
        event.cycleId,
        decision: event.decision,
        reason: event.reason,
      );
      emit(CycleReleaseState(
        status: CycleReleaseStatus.success,
        release: release,
      ));
    } on ApiException catch (e) {
      emit(CycleReleaseState(
        status: CycleReleaseStatus.failure,
        error: e.message,
      ));
    }
  }
}
