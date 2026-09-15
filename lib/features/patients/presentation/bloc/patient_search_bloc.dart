import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/utils/debouncer.dart';
import '../../data/models/patient_data.dart';
import '../../data/repositories/patient_repository.dart';

part 'patient_search_event.dart';
part 'patient_search_state.dart';

class PatientSearchBloc extends Bloc<PatientSearchEvent, PatientSearchState> {
  final PatientRepository _repository;
  final _debouncer = Debouncer(delay: const Duration(milliseconds: 300));

  PatientSearchBloc(this._repository) : super(const PatientSearchState()) {
    on<PatientSearchQueryChanged>(_onQueryChanged);
    on<PatientSearchSubmitted>(_onSubmitted);
    on<PatientSearchCleared>(_onCleared);
  }

  void _onQueryChanged(
    PatientSearchQueryChanged event,
    Emitter<PatientSearchState> emit,
  ) {
    emit(state.copyWith(query: event.query));
    _debouncer.run(() {
      if (!isClosed) add(PatientSearchSubmitted(event.query));
    });
  }

  Future<void> _onSubmitted(
    PatientSearchSubmitted event,
    Emitter<PatientSearchState> emit,
  ) async {
    emit(state.copyWith(status: PatientSearchStatus.loading, error: null));
    try {
      final results = await _repository.search(event.query);
      emit(state.copyWith(
        status: PatientSearchStatus.success,
        results: results,
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(
        status: PatientSearchStatus.failure,
        error: e.message,
      ));
    }
  }

  Future<void> _onCleared(
    PatientSearchCleared event,
    Emitter<PatientSearchState> emit,
  ) async {
    emit(const PatientSearchState());
  }

  @override
  Future<void> close() {
    _debouncer.dispose();
    return super.close();
  }
}
