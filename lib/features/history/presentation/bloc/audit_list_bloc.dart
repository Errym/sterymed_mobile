import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/utils/error_message.dart';
import '../../data/models/audit_event_data.dart';
import '../../data/repositories/audit_repository.dart';

part 'audit_list_event.dart';
part 'audit_list_state.dart';

class AuditListBloc extends Bloc<AuditListEvent, AuditListState> {
  final AuditRepository _repository;

  /// Bumped by every request that replaces the list: a slow answer for an
  /// older filter never overwrites the list of the current one.
  int _generation = 0;

  AuditListBloc(this._repository) : super(const AuditListState()) {
    on<LoadAuditEvents>(_onLoad);
    on<RefreshAuditEvents>(_onRefresh);
    on<LoadMoreAuditEvents>(_onLoadMore);
    on<FilterAuditEvents>(_onFilter);
    on<ApplyAdvancedAuditFilters>(_onApplyAdvanced);
  }

  ({Map<String, String> actors, Map<String, String> subjectTypes}) _accumulate(
    List<AuditEventData> events,
  ) {
    final actors = Map<String, String>.of(state.seenActors);
    final subjectTypes = Map<String, String>.of(state.seenSubjectTypes);
    for (final e in events) {
      if (e.actorId != null && e.actorLabel != null) {
        actors[e.actorId!] = e.actorLabel!;
      }
      if (e.subjectType != null) {
        subjectTypes[e.subjectType!] = e.subjectTypeLabel ?? e.subjectType!;
      }
    }
    return (actors: actors, subjectTypes: subjectTypes);
  }

  Future<void> _onLoad(
    LoadAuditEvents event,
    Emitter<AuditListState> emit,
  ) async {
    final generation = ++_generation;
    emit(state.copyWith(status: AuditStatus.loading, error: null));
    try {
      final page = await _repository.list(
        action: state.actionFilter,
        actorId: state.actorIdFilter,
        subjectType: state.subjectTypeFilter,
        from: state.fromFilter,
        to: state.toFilter,
      );
      if (generation != _generation) return;
      final acc = _accumulate(page.items);
      emit(state.copyWith(
        status: AuditStatus.success,
        events: page.items,
        nextCursor: page.nextCursor,
        clearNextCursor: page.nextCursor == null,
        seenActors: acc.actors,
        seenSubjectTypes: acc.subjectTypes,
      ));
    } on ApiException catch (e) {
      if (generation != _generation) return;
      emit(state.copyWith(
        status: AuditStatus.failure,
        error: ErrorMessage.from(e),
      ));
    }
  }

  Future<void> _onRefresh(
    RefreshAuditEvents event,
    Emitter<AuditListState> emit,
  ) async {
    final generation = ++_generation;
    try {
      final page = await _repository.list(
        action: state.actionFilter,
        actorId: state.actorIdFilter,
        subjectType: state.subjectTypeFilter,
        from: state.fromFilter,
        to: state.toFilter,
        forceRefresh: true,
      );
      if (generation != _generation) return;
      final acc = _accumulate(page.items);
      emit(state.copyWith(
        status: AuditStatus.success,
        events: page.items,
        nextCursor: page.nextCursor,
        clearNextCursor: page.nextCursor == null,
        seenActors: acc.actors,
        seenSubjectTypes: acc.subjectTypes,
      ));
    } on ApiException catch (e) {
      if (generation != _generation) return;
      emit(state.copyWith(
        status: AuditStatus.failure,
        error: ErrorMessage.from(e),
      ));
    }
  }

  Future<void> _onLoadMore(
    LoadMoreAuditEvents event,
    Emitter<AuditListState> emit,
  ) async {
    final cursor = state.nextCursor;
    if (cursor == null || state.isLoadingMore) return;
    final generation = _generation;
    emit(state.copyWith(isLoadingMore: true));
    try {
      final page = await _repository.list(
        cursor: cursor,
        action: state.actionFilter,
        actorId: state.actorIdFilter,
        subjectType: state.subjectTypeFilter,
        from: state.fromFilter,
        to: state.toFilter,
      );
      if (generation != _generation) return;
      final acc = _accumulate(page.items);
      emit(state.copyWith(
        events: [...state.events, ...page.items],
        nextCursor: page.nextCursor,
        clearNextCursor: page.nextCursor == null,
        isLoadingMore: false,
        seenActors: acc.actors,
        seenSubjectTypes: acc.subjectTypes,
      ));
    } on ApiException catch (e) {
      if (generation != _generation) return;
      emit(state.copyWith(isLoadingMore: false, error: ErrorMessage.from(e)));
    }
  }

  void _onFilter(FilterAuditEvents event, Emitter<AuditListState> emit) {
    // Rows of the previous filter must not sit under the new one while the
    // answer is on its way.
    emit(state.copyWith(
      actionFilter: event.action,
      clearActionFilter: event.action == null,
      events: const [],
      clearNextCursor: true,
    ));
    add(const LoadAuditEvents());
  }

  void _onApplyAdvanced(
    ApplyAdvancedAuditFilters event,
    Emitter<AuditListState> emit,
  ) {
    emit(state.copyWith(
      actorIdFilter: event.actorId,
      actorLabelFilter: event.actorLabel,
      clearActorFilter: event.actorId == null,
      subjectTypeFilter: event.subjectType,
      clearSubjectTypeFilter: event.subjectType == null,
      fromFilter: event.from,
      clearFromFilter: event.from == null,
      toFilter: event.to,
      clearToFilter: event.to == null,
      events: const [],
      clearNextCursor: true,
    ));
    add(const LoadAuditEvents());
  }
}
