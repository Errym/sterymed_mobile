import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/network/cursor_page.dart';
import '../../data/models/prosthetic_case_data.dart';
import '../../data/models/prosthetic_summary_data.dart';
import '../../data/repositories/prosthetic_repository.dart';

part 'prosthetic_case_list_event.dart';
part 'prosthetic_case_list_state.dart';

class ProstheticCaseListBloc
    extends Bloc<ProstheticCaseListEvent, ProstheticCaseListState> {
  final ProstheticRepository _repository;

  /// Bumped by every request that replaces the list. A response that comes
  /// back after a newer request started is dropped, so a slow answer for an
  /// OLD filter set can never overwrite the list of the NEW one (brief §10).
  int _generation = 0;

  ProstheticCaseListBloc(this._repository)
      : super(const ProstheticCaseListState()) {
    on<LoadProstheticCases>(_onLoad);
    on<FilterProstheticCases>(_onFilter);
    on<LoadMoreProstheticCases>(_onLoadMore);
  }

  static String? _date(DateTime? d) => d?.toIso8601String().split('T').first;

  Future<CursorPage<ProstheticCaseData>> _page(
    ProstheticCaseListFilters f, {
    String? cursor,
  }) =>
      _repository.list(
        cursor: cursor,
        patientReference: f.patientReference,
        practitionerId: f.practitionerId,
        laboratoryId: f.laboratoryId,
        workType: f.workType,
        status: f.status,
        from: _date(f.from),
        to: _date(f.to),
        scope: f.scope,
      );

  /// The total is a nicety: if only this call fails the list still shows.
  Future<ProstheticSummaryData?> _summary(ProstheticCaseListFilters f) async {
    try {
      return await _repository.summary(
        patientReference: f.patientReference,
        practitionerId: f.practitionerId,
        laboratoryId: f.laboratoryId,
        workType: f.workType,
        status: f.status,
        from: _date(f.from),
        to: _date(f.to),
        scope: f.scope,
      );
    } on ApiException {
      return null;
    }
  }

  Future<void> _fetch(
    Emitter<ProstheticCaseListState> emit, {
    required ProstheticCaseListFilters filters,
  }) async {
    final generation = ++_generation;
    // The filters are part of the state from the first moment, not only once
    // an answer arrives: chips, retry and refresh all see what the user chose.
    emit(state.copyWith(
      status: ProstheticCaseListStatus.loading,
      error: null,
      filters: filters,
      cases: const [],
      clearNextCursor: true,
      clearTotal: true,
      isLoadingMore: false,
    ));
    try {
      final pageFuture = _page(filters);
      final summaryFuture = _summary(filters);
      final page = await pageFuture;
      final summary = await summaryFuture;
      if (generation != _generation) return;
      emit(state.copyWith(
        status: ProstheticCaseListStatus.success,
        cases: page.items,
        nextCursor: page.nextCursor,
        clearNextCursor: page.nextCursor == null,
        total: summary?.total,
      ));
    } on ApiException catch (e) {
      if (generation != _generation) return;
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
    final generation = _generation;
    emit(state.copyWith(isLoadingMore: true));
    try {
      // A cursor only marks where the last page ended: the filters have to
      // travel with it or page 2 would silently be unfiltered.
      final page = await _page(state.filters, cursor: cursor);
      if (generation != _generation) return;
      emit(state.copyWith(
        cases: [...state.cases, ...page.items],
        nextCursor: page.nextCursor,
        clearNextCursor: page.nextCursor == null,
        isLoadingMore: false,
      ));
    } on ApiException catch (e) {
      if (generation != _generation) return;
      emit(state.copyWith(isLoadingMore: false, error: e.message));
    }
  }
}
