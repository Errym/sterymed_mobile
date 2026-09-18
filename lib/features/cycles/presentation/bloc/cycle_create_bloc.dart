import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/api_exception.dart';
import '../../data/models/cycle_data.dart';
import '../../data/repositories/cycle_repository.dart';

part 'cycle_create_event.dart';
part 'cycle_create_state.dart';

class CycleCreateBloc extends Bloc<CycleCreateEvent, CycleCreateState> {
  final CycleRepository _repository;

  CycleCreateBloc(this._repository) : super(const CycleCreateState()) {
    on<SubmitCycleCreate>(_onSubmit);
  }

  Future<void> _onSubmit(
    SubmitCycleCreate event,
    Emitter<CycleCreateState> emit,
  ) async {
    emit(state.copyWith(status: CycleCreateStatus.loading, error: null));
    try {
      final cycle = await _repository.create({
        'device_id': event.deviceId,
        if (event.programId != null) 'device_program_id': event.programId,
        if (event.notes != null && event.notes!.isNotEmpty)
          'notes': event.notes,
      });
      emit(CycleCreateState(
        status: CycleCreateStatus.success,
        cycle: cycle,
      ));
    } on ApiException catch (e) {
      emit(CycleCreateState(
        status: CycleCreateStatus.failure,
        error: e.message,
      ));
    }
  }
}
