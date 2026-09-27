import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/api_exception.dart';
import '../../data/models/prosthetic_case_data.dart';
import '../../data/repositories/prosthetic_repository.dart';

part 'prosthetic_case_list_event.dart';
part 'prosthetic_case_list_state.dart';

class ProstheticCaseListBloc
    extends Bloc<ProstheticCaseListEvent, ProstheticCaseListState> {
  final ProstheticRepository _repository;

  ProstheticCaseListBloc(this._repository)
      : super(const ProstheticCaseListState()) {
    on<LoadProstheticCases>(_onLoad);
    on<FilterProstheticCases>(_onFilter);
    on<LoadMoreProstheticCases>(_onLoadMore);
  }

  Future<void> _fetch(
    Emitter<ProstheticCaseListState> emit, {
    required ProstheticCaseListFilters filters,
  }) async {
    emit(state.copyWith(status: ProstheticCaseListStatus.loading, error: null));
    try {
      final page = await _repository.list(
        patientReference: filters.patientReference,
        practitionerId: filters.practitionerId,
        laboratoryId: filters.laboratoryId,
        workType: filters.workType,
        status: filters.status,
        from: filters.from?.toIso8601String().split('T').first,
        to: filters.to?.toIso8601String().split('T').first,
      );
      emit(state.copyWith(
        status: ProstheticCaseListStatus.success,
        cases: page.items,
        nextCursor: page.nextCursor,
        clearNextCursor: page.nextCursor == null,
        filters: filters,
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(
        status: ProstheticCaseListStatus.failure,
        error: e.message,
      ));
    }
  }

  Future<void> _onLoad(
    LoadProstheticCases event,
    Emitter<ProstheticCaseListState> emit,
  ) =>
      _fetch(emit, filters: state.filters);

  Future<void> _onFilter(
    FilterProstheticCases event,
    Emitter<ProstheticCaseListState> emit,
  ) =>
      _fetch(emit, filters: event.filters);

  Future<void> _onLoadMore(
    LoadMoreProstheticCases event,
    Emitter<ProstheticCaseListState> emit,
  ) async {
    final cursor = state.nextCursor;
    if (cursor == null || state.isLoadingMore) return;
    emit(state.copyWith(isLoadingMore: true));
    try {
      final page = await _repository.loadMore(cursor);
      emit(state.copyWith(
        cases: [...state.cases, ...page.items],
        nextCursor: page.nextCursor,
        clearNextCursor: page.nextCursor == null,
        isLoadingMore: false,
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(isLoadingMore: false, error: e.message));
    }
  }
}
