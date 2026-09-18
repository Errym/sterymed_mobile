import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/api_exception.dart';
import '../../data/models/non_conformity_data.dart';
import '../../data/repositories/non_conformity_repository.dart';

part 'non_conformity_list_event.dart';
part 'non_conformity_list_state.dart';

class NonConformityListBloc
    extends Bloc<NonConformityListEvent, NonConformityListState> {
  final NonConformityRepository _repository;

  NonConformityListBloc(this._repository)
      : super(const NonConformityListState()) {
    on<LoadNonConformities>(_onLoad);
    on<FilterNonConformities>(_onFilter);
  }

  Future<void> _onLoad(
    LoadNonConformities event,
    Emitter<NonConformityListState> emit,
  ) async {
    emit(state.copyWith(status: NonConformityStatus.loading));
    try {
      final items = await _repository.list(status: state.statusFilter);
      emit(state.copyWith(
        status: NonConformityStatus.success,
        items: items,
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(
        status: NonConformityStatus.failure,
        error: e.message,
      ));
    }
  }

  void _onFilter(
    FilterNonConformities event,
    Emitter<NonConformityListState> emit,
  ) {
    if (event.status == null) {
      emit(state.copyWith(clearStatusFilter: true));
    } else {
      emit(state.copyWith(statusFilter: event.status));
    }
    add(const LoadNonConformities());
  }
}
