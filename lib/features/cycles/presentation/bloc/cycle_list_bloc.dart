import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/api_exception.dart';
import '../../data/models/cycle_data.dart';
import '../../data/repositories/cycle_repository.dart';

part 'cycle_list_event.dart';
part 'cycle_list_state.dart';

class CycleListBloc extends Bloc<CycleListEvent, CycleListState> {
  final CycleRepository _repository;

  CycleListBloc(this._repository) : super(const CycleListState()) {
    on<LoadCycles>(_onLoad);
    on<RefreshCycles>(_onRefresh);
    on<FilterCycles>(_onFilter);
  }

  Future<void> _onLoad(LoadCycles event, Emitter<CycleListState> emit) async {
    emit(state.copyWith(status: CycleListStatus.loading, error: null));
    try {
      final cycles = await _repository.list();
      emit(state.copyWith(status: CycleListStatus.success, cycles: cycles));
    } on ApiException catch (e) {
      emit(state.copyWith(status: CycleListStatus.failure, error: e.message));
    }
  }

  Future<void> _onRefresh(
    RefreshCycles event,
    Emitter<CycleListState> emit,
  ) async {
    try {
      final cycles = await _repository.list();
      emit(state.copyWith(status: CycleListStatus.success, cycles: cycles));
    } on ApiException catch (e) {
      emit(state.copyWith(status: CycleListStatus.failure, error: e.message));
    }
  }

  void _onFilter(FilterCycles event, Emitter<CycleListState> emit) {
    emit(state.copyWith(selectedStatus: event.status));
  }
}
