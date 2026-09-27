import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/api_exception.dart';
import '../../data/models/audit_event_data.dart';
import '../../data/repositories/audit_repository.dart';

part 'audit_list_event.dart';
part 'audit_list_state.dart';

class AuditListBloc extends Bloc<AuditListEvent, AuditListState> {
  final AuditRepository _repository;

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
    emit(state.copyWith(status: AuditStatus.loading, error: null));
    try {
      final page = await _repository.list(
        action: state.actionFilter,
        actorId: state.actorIdFilter,
        subjectType: state.subjectTypeFilter,
        from: state.fromFilter,
        to: state.toFilter,
      );
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
      emit(state.copyWith(status: AuditStatus.failure, error: e.message));
    }
  }

  Future<void> _onRefresh(
    RefreshAuditEvents event,
    Emitter<AuditListState> emit,
  ) async {
    try {
      final page = await _repository.list(
        action: state.actionFilter,
        actorId: state.actorIdFilter,
        subjectType: state.subjectTypeFilter,
        from: state.fromFilter,
        to: state.toFilter,
        forceRefresh: true,
      );
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
      emit(state.copyWith(status: AuditStatus.failure, error: e.message));
    }
  }

  Future<void> _onLoadMore(
    LoadMoreAuditEvents event,
    Emitter<AuditListState> emit,
  ) async {
    final cursor = state.nextCursor;
    if (cursor == null || state.isLoadingMore) return;
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
      emit(state.copyWith(isLoadingMore: false, error: e.message));
    }
  }

  void _onFilter(FilterAuditEvents event, Emitter<AuditListState> emit) {
    emit(state.copyWith(
      actionFilter: event.action,
      clearActionFilter: event.action == null,
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
    ));
    add(const LoadAuditEvents());
  }
}
