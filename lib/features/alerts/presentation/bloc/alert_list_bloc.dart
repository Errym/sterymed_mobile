import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/utils/error_message.dart';
import '../../data/models/alert_data.dart';
import '../../data/repositories/alert_repository.dart';

part 'alert_list_event.dart';
part 'alert_list_state.dart';

class AlertListBloc extends Bloc<AlertListEvent, AlertListState> {
  final AlertRepository _repository;

  /// Bumped by every request that replaces the list: a slow answer for an
  /// older filter never overwrites the list of the current one.
  int _generation = 0;
  int _noticeSeq = 0;

  AlertListBloc(this._repository) : super(const AlertListState()) {
    on<LoadAlerts>(_onLoad);
    on<RefreshAlerts>(_onRefresh);
    on<FilterAlerts>(_onFilter);
    on<LoadMoreAlerts>(_onLoadMore);
    on<ResolveAlert>(_onResolve);
  }

  AlertNotice _notice(String message, {bool isError = false}) =>
      AlertNotice(++_noticeSeq, message, isError: isError);

  Future<void> _fetch(
    Emitter<AlertListState> emit, {
    required String? type,
    required String? stateFilter,
    bool forceRefresh = false,
    bool showLoading = true,
  }) async {
    final generation = ++_generation;
    // The filters are part of the state from the first moment.
    emit(state.copyWith(
      status: showLoading ? AlertListStatus.loading : state.status,
      typeFilter: type,
      clearTypeFilter: type == null,
      stateFilter: stateFilter,
      clearStateFilter: stateFilter == null,
      alerts: showLoading ? const [] : state.alerts,
      clearNextCursor: showLoading,
    ));
    try {
      final page = await _repository.getActiveAlerts(
        forceRefresh: forceRefresh,
        type: type,
        state: stateFilter,
      );
      if (generation != _generation) return;
      emit(state.copyWith(
        status: AlertListStatus.success,
        alerts: page.items,
        nextCursor: page.nextCursor,
        clearNextCursor: page.nextCursor == null,
      ));
    } on ApiException catch (e) {
      if (generation != _generation) return;
      emit(state.copyWith(status: AlertListStatus.failure, error: e.message));
    }
  }

  Future<void> _onLoad(LoadAlerts event, Emitter<AlertListState> emit) =>
      _fetch(emit, type: state.typeFilter, stateFilter: state.stateFilter);

  Future<void> _onRefresh(
    RefreshAlerts event,
    Emitter<AlertListState> emit,
  ) =>
      _fetch(
        emit,
        type: state.typeFilter,
        stateFilter: state.stateFilter,
        forceRefresh: true,
        // Pull to refresh keeps the list on screen while it reloads.
        showLoading: false,
      );

  Future<void> _onFilter(FilterAlerts event, Emitter<AlertListState> emit) =>
      _fetch(emit, type: event.type, stateFilter: event.state);

  Future<void> _onLoadMore(
    LoadMoreAlerts event,
    Emitter<AlertListState> emit,
  ) async {
    final cursor = state.nextCursor;
    if (cursor == null || state.isLoadingMore) return;
    final generation = _generation;
    emit(state.copyWith(isLoadingMore: true));
    try {
      final page = await _repository.loadMore(
        cursor,
        type: state.typeFilter,
        state: state.stateFilter,
      );
      if (generation != _generation) return;
      emit(state.copyWith(
        alerts: [...state.alerts, ...page.items],
        nextCursor: page.nextCursor,
        clearNextCursor: page.nextCursor == null,
        isLoadingMore: false,
      ));
    } on ApiException catch (e) {
      if (generation != _generation) return;
      emit(state.copyWith(isLoadingMore: false, error: e.message));
    }
  }

  /// Not optimistic: the alert only leaves the open list once the server has
  /// said so, and the answer (success or the real French reason) is shown.
  Future<void> _onResolve(
    ResolveAlert event,
    Emitter<AlertListState> emit,
  ) async {
    final id = event.alertId;
    if (state.resolving.contains(id)) return;
    emit(state.copyWith(resolving: {...state.resolving, id}));
    try {
      await _repository.resolveAlert(id);
      _afterResolve(emit, id, 'Alerte résolue.');
    } on ApiException catch (e) {
      if (e.statusCode == 409) {
        // Someone else resolved it first: the goal is reached either way.
        _afterResolve(emit, id, 'Cette alerte était déjà résolue.');
        return;
      }
      emit(state.copyWith(
        resolving: {...state.resolving}..remove(id),
        notice: _notice(ErrorMessage.from(e), isError: true),
      ));
    }
  }

  void _afterResolve(Emitter<AlertListState> emit, String id, String message) {
    final left = {...state.resolving}..remove(id);
    // In the "open" view a resolved alert leaves; in other views it stays,
    // and the next refresh shows its resolved state.
    final alerts = state.stateFilter == 'open'
        ? state.alerts.where((a) => a.id != id).toList(growable: false)
        : state.alerts;
    emit(state.copyWith(
      alerts: alerts,
      resolving: left,
      notice: _notice(message),
    ));
  }
}
