import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/api_exception.dart';
import '../../data/models/stock_movement_data.dart';
import '../../data/repositories/stock_repository.dart';

part 'stock_adjust_event.dart';
part 'stock_adjust_state.dart';

class StockAdjustBloc extends Bloc<StockAdjustEvent, StockAdjustState> {
  final StockRepository _repository;

  StockAdjustBloc(this._repository) : super(const StockAdjustState()) {
    on<SubmitStockAdjust>(_onSubmit);
  }

  Future<void> _onSubmit(
    SubmitStockAdjust event,
    Emitter<StockAdjustState> emit,
  ) async {
    emit(state.copyWith(status: StockAdjustStatus.loading, error: null));
    try {
      final m = await _repository.adjust(
        batchId: event.batchId,
        locationId: event.locationId,
        qty: event.qty,
        reason: event.reason,
      );
      emit(StockAdjustState(
        status: StockAdjustStatus.success,
        movement: m,
      ));
    } on ApiException catch (e) {
      emit(StockAdjustState(
        status: StockAdjustStatus.failure,
        error: e.message,
      ));
    }
  }
}
