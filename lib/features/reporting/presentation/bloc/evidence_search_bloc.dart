import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/utils/error_message.dart';
import '../../data/models/evidence_search_result_data.dart';
import '../../data/repositories/evidence_search_repository.dart';

part 'evidence_search_event.dart';
part 'evidence_search_state.dart';

class EvidenceSearchBloc
    extends Bloc<EvidenceSearchEvent, EvidenceSearchState> {
  final EvidenceSearchRepository _repository;

  /// A slow answer for an older search never replaces the current one.
  int _generation = 0;

  EvidenceSearchBloc(this._repository) : super(const EvidenceSearchState()) {
    on<SearchEvidence>(_onSearch);
    on<LoadMoreEvidence>(_onLoadMore);
  }

  Future<void> _onSearch(
    SearchEvidence event,
    Emitter<EvidenceSearchState> emit,
  ) async {
    final generation = ++_generation;
    emit(state.copyWith(
      status: EvidenceSearchStatus.loading,
      results: const [],
      clearNextCursor: true,
      error: null,
      patientReference: event.patientReference,
      clearPatientReference: event.patientReference == null,
      cycleNumber: event.cycleNumber,
      clearCycleNumber: event.cycleNumber == null,
      batchNumber: event.batchNumber,
      clearBatchNumber: event.batchNumber == null,
      from: event.from,
      clearFrom: event.from == null,
      to: event.to,
      clearTo: event.to == null,
    ));
    try {
      final page = await _repository.search(
        patientReference: event.patientReference,
        cycleNumber: event.cycleNumber,
        batchNumber: event.batchNumber,
        from: event.from,
        to: event.to,
      );
      if (generation != _generation) return;
      emit(state.copyWith(
        status: EvidenceSearchStatus.success,
        results: page.items,
        nextCursor: page.nextCursor,
        clearNextCursor: page.nextCursor == null,
        hasSearched: true,
      ));
    } on ApiException catch (e) {
      if (generation != _generation) return;
      emit(state.copyWith(
        status: EvidenceSearchStatus.failure,
        error: ErrorMessage.from(e),
        // Even a failed first search counts as "searched": the screen shows
        // the error with a retry, never the "launch a search" invitation.
        hasSearched: true,
      ));
    }
  }

  Future<void> _onLoadMore(
    LoadMoreEvidence event,
    Emitter<EvidenceSearchState> emit,
  ) async {
    final cursor = state.nextCursor;
    if (cursor == null || state.isLoadingMore) return;
    final generation = _generation;
    emit(state.copyWith(isLoadingMore: true));
    try {
      final page = await _repository.search(
        cursor: cursor,
        patientReference: state.patientReference,
        cycleNumber: state.cycleNumber,
        batchNumber: state.batchNumber,
        from: state.from,
        to: state.to,
      );
      if (generation != _generation) return;
      emit(state.copyWith(
        results: [...state.results, ...page.items],
        nextCursor: page.nextCursor,
        clearNextCursor: page.nextCursor == null,
        isLoadingMore: false,
      ));
    } on ApiException catch (e) {
      if (generation != _generation) return;
      emit(state.copyWith(isLoadingMore: false, error: ErrorMessage.from(e)));
    }
  }
}
