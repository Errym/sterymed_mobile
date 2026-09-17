import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/api_exception.dart';
import '../../data/repositories/stock_repository.dart';

part 'stock_action_state.dart';

class StockActionCubit extends Cubit<StockActionState> {
  final StockRepository _repository;

  StockActionCubit(this._repository) : super(const StockActionState());

  Future<bool> issue({
    required String batchId,
    required String locationId,
    required int qty,
    String? reason,
  }) =>
      _run(() => _repository.issue(
            batchId: batchId,
            locationId: locationId,
            qty: qty,
            reason: reason,
          ));

  Future<bool> adjust({
    required String batchId,
    required String locationId,
    required int qty,
    required String reason,
  }) =>
      _run(() => _repository.adjust(
            batchId: batchId,
            locationId: locationId,
            qty: qty,
            reason: reason,
          ));

  Future<bool> transfer({
    required String batchId,
    required String fromLocationId,
    required String toLocationId,
    required int qty,
    String? reason,
  }) =>
      _run(() => _repository.transfer(
            batchId: batchId,
            fromLocationId: fromLocationId,
            toLocationId: toLocationId,
            qty: qty,
            reason: reason,
          ));

  Future<bool> _run(Future<void> Function() op) async {
    emit(const StockActionState(status: StockActionStatus.loading));
    try {
      await op();
      emit(const StockActionState(status: StockActionStatus.success));
      return true;
    } on ApiException catch (e) {
      emit(StockActionState(
        status: StockActionStatus.failure,
        error: e.message,
      ));
      return false;
    }
  }
}
