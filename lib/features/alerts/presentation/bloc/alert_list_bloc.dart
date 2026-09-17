import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/api_exception.dart';
import '../../data/models/alert_data.dart';
import '../../data/repositories/alert_repository.dart';

part 'alert_list_event.dart';
part 'alert_list_state.dart';

class AlertListBloc extends Bloc<AlertListEvent, AlertListState> {
  final AlertRepository _repository;

  AlertListBloc(this._repository) : super(const AlertListState()) {
    on<LoadAlerts>(_onLoad);
    on<RefreshAlerts>(_onRefresh);
    on<ResolveAlert>(_onResolve);
  }

  Future<void> _onLoad(LoadAlerts event, Emitter<AlertListState> emit) async {
    emit(state.copyWith(status: AlertListStatus.loading, error: null));
    try {
      final alerts = await _repository.getActiveAlerts();
      emit(state.copyWith(status: AlertListStatus.success, alerts: alerts));
    } on ApiException catch (e) {
      emit(state.copyWith(status: AlertListStatus.failure, error: e.message));
    }
  }

  Future<void> _onRefresh(
    RefreshAlerts event,
    Emitter<AlertListState> emit,
  ) async {
    try {
      final alerts = await _repository.getActiveAlerts(forceRefresh: true);
      emit(state.copyWith(status: AlertListStatus.success, alerts: alerts));
    } on ApiException catch (e) {
      emit(state.copyWith(status: AlertListStatus.failure, error: e.message));
    }
  }

  Future<void> _onResolve(
    ResolveAlert event,
    Emitter<AlertListState> emit,
  ) async {
    // Optimistic: remove from UI immediately.
    final previous = state.alerts;
    final optimistic =
        previous.where((a) => a.id != event.alertId).toList(growable: false);
    emit(state.copyWith(alerts: optimistic));

    try {
      await _repository.resolveAlert(event.alertId);
    } on ApiException catch (e) {
      if (e.statusCode == 409) return; // already resolved — keep optimistic
      // Failure — restore and surface error.
      emit(state.copyWith(alerts: previous, error: e.message));
    }
  }
}
