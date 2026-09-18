import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/api_exception.dart';
import '../../data/models/stock_movement_data.dart';
import '../../data/repositories/stock_repository.dart';

part 'stock_transfer_event.dart';
part 'stock_transfer_state.dart';

class StockTransferBloc extends Bloc<StockTransferEvent, StockTransferState> {
  final StockRepository _repository;

  StockTransferBloc(this._repository) : super(const StockTransferState()) {
    on<SubmitStockTransfer>(_onSubmit);
  }

  Future<void> _onSubmit(
    SubmitStockTransfer event,
    Emitter<StockTransferState> emit,
  ) async {
    emit(state.copyWith(status: StockTransferStatus.loading, error: null));
    try {
      final m = await _repository.transfer(
        batchId: event.batchId,
        fromLocationId: event.fromLocationId,
        toLocationId: event.toLocationId,
        qty: event.qty,
        reason: event.reason,
      );
      emit(StockTransferState(
        status: StockTransferStatus.success,
        movement: m,
      ));
    } on ApiException catch (e) {
      emit(StockTransferState(
        status: StockTransferStatus.failure,
        error: e.message,
      ));
    }
  }
}
