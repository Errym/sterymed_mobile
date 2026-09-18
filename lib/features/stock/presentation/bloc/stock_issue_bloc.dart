import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/api_exception.dart';
import '../../data/models/stock_movement_data.dart';
import '../../data/repositories/stock_repository.dart';

part 'stock_issue_event.dart';
part 'stock_issue_state.dart';

class StockIssueBloc extends Bloc<StockIssueEvent, StockIssueState> {
  final StockRepository _repository;

  StockIssueBloc(this._repository) : super(const StockIssueState()) {
    on<SubmitStockIssue>(_onSubmit);
  }

  Future<void> _onSubmit(
    SubmitStockIssue event,
    Emitter<StockIssueState> emit,
  ) async {
    emit(state.copyWith(status: StockIssueStatus.loading, error: null));
    try {
      final m = await _repository.issue(
        batchId: event.batchId,
        locationId: event.locationId,
        qty: event.qty,
        reason: event.reason,
      );
      emit(StockIssueState(
        status: StockIssueStatus.success,
        movement: m,
      ));
    } on ApiException catch (e) {
      emit(StockIssueState(
        status: StockIssueStatus.failure,
        error: e.message,
      ));
    }
  }
}
