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
    on<FilterAuditEvents>(_onFilter);
  }

  Future<void> _onLoad(
    LoadAuditEvents event,
    Emitter<AuditListState> emit,
  ) async {
    emit(state.copyWith(status: AuditStatus.loading, error: null));
    try {
      final events = await _repository.list(action: state.actionFilter);
      emit(state.copyWith(status: AuditStatus.success, events: events));
    } on ApiException catch (e) {
      emit(state.copyWith(status: AuditStatus.failure, error: e.message));
    }
  }

  Future<void> _onRefresh(
    RefreshAuditEvents event,
    Emitter<AuditListState> emit,
  ) async {
    try {
      final events = await _repository.list(action: state.actionFilter);
      emit(state.copyWith(status: AuditStatus.success, events: events));
    } on ApiException catch (e) {
      emit(state.copyWith(status: AuditStatus.failure, error: e.message));
    }
  }

  void _onFilter(FilterAuditEvents event, Emitter<AuditListState> emit) {
    emit(state.copyWith(actionFilter: event.action));
    add(const LoadAuditEvents());
  }
}
