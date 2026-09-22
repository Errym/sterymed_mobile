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
    on<LoadMoreCycles>(_onLoadMore);
    on<FilterCycles>(_onFilter);
    on<SearchCycles>(_onSearch);
  }

  Future<void> _onLoad(LoadCycles event, Emitter<CycleListState> emit) async {
    emit(state.copyWith(status: CycleListStatus.loading, error: null));
    try {
      final page = await _repository.list(forceRefresh: true);
      emit(state.copyWith(
        status: CycleListStatus.success,
        cycles: page.items,
        nextCursor: page.nextCursor,
        clearNextCursor: page.nextCursor == null,
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(status: CycleListStatus.failure, error: e.message));
    }
  }

  Future<void> _onRefresh(
    RefreshCycles event,
    Emitter<CycleListState> emit,
  ) async {
    try {
      final page = await _repository.list(forceRefresh: true);
      emit(state.copyWith(
        status: CycleListStatus.success,
        cycles: page.items,
        nextCursor: page.nextCursor,
        clearNextCursor: page.nextCursor == null,
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(status: CycleListStatus.failure, error: e.message));
    }
  }

  Future<void> _onLoadMore(
    LoadMoreCycles event,
    Emitter<CycleListState> emit,
  ) async {
    final cursor = state.nextCursor;
    if (cursor == null || state.isLoadingMore) return;
    emit(state.copyWith(isLoadingMore: true));
    try {
      final page = await _repository.loadMore(cursor);
      emit(state.copyWith(
        cycles: [...state.cycles, ...page.items],
        nextCursor: page.nextCursor,
        clearNextCursor: page.nextCursor == null,
        isLoadingMore: false,
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(isLoadingMore: false, error: e.message));
    }
  }

  void _onFilter(FilterCycles event, Emitter<CycleListState> emit) {
    if (event.status == null) {
      // Explicitly clear the filter — this is the "Tous les cycles" case.
      emit(state.copyWith(clearStatusFilter: true));
    } else {
      emit(state.copyWith(selectedStatus: event.status));
    }
  }

  void _onSearch(SearchCycles event, Emitter<CycleListState> emit) {
    emit(state.copyWith(searchQuery: event.query));
  }
}
