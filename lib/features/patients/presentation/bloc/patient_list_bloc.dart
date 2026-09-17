import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/api_exception.dart';
import '../../data/models/patient_create_request.dart';
import '../../data/models/patient_data.dart';
import '../../data/repositories/patient_repository.dart';

part 'patient_list_event.dart';
part 'patient_list_state.dart';

class PatientListBloc extends Bloc<PatientListEvent, PatientListState> {
  final PatientRepository _repository;

  PatientListBloc(this._repository) : super(const PatientListState()) {
    on<LoadPatients>(_onLoad);
    on<SearchPatients>(_onSearch);
    on<CreatePatient>(_onCreate);
  }

  Future<void> _onLoad(LoadPatients e, Emitter<PatientListState> emit) async {
    emit(state.copyWith(status: PatientListStatus.loading, error: null));
    try {
      final list = await _repository.search('');
      emit(state.copyWith(status: PatientListStatus.success, patients: list));
    } on ApiException catch (ex) {
      emit(state.copyWith(status: PatientListStatus.failure, error: ex.message));
    }
  }

  Future<void> _onSearch(SearchPatients e, Emitter<PatientListState> emit) async {
    emit(state.copyWith(query: e.query, status: PatientListStatus.loading));
    try {
      final list = await _repository.search(e.query);
      emit(state.copyWith(status: PatientListStatus.success, patients: list));
    } on ApiException catch (ex) {
      emit(state.copyWith(status: PatientListStatus.failure, error: ex.message));
    }
  }

  Future<void> _onCreate(CreatePatient e, Emitter<PatientListState> emit) async {
    try {
      await _repository.create(e.request);
      add(const LoadPatients());
    } on ApiException catch (ex) {
      emit(state.copyWith(error: ex.message));
    }
  }
}
