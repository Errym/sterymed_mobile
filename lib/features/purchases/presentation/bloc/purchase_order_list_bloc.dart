import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/api_exception.dart';
import '../../data/models/purchase_order_data.dart';
import '../../data/repositories/purchase_repository.dart';

part 'purchase_order_list_event.dart';
part 'purchase_order_list_state.dart';

class PurchaseOrderListBloc
    extends Bloc<PurchaseOrderListEvent, PurchaseOrderListState> {
  final PurchaseRepository _repository;

  PurchaseOrderListBloc(this._repository)
      : super(const PurchaseOrderListState()) {
    on<LoadPurchaseOrders>(_onLoad);
    on<RefreshPurchaseOrders>(_onRefresh);
  }

  Future<void> _onLoad(
    LoadPurchaseOrders event,
    Emitter<PurchaseOrderListState> emit,
  ) async {
    emit(state.copyWith(status: PurchaseOrderListStatus.loading, error: null));
    try {
      final orders = await _repository.list();
      emit(state.copyWith(
        status: PurchaseOrderListStatus.success,
        orders: orders,
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(
        status: PurchaseOrderListStatus.failure,
        error: e.message,
      ));
    }
  }

  Future<void> _onRefresh(
    RefreshPurchaseOrders event,
    Emitter<PurchaseOrderListState> emit,
  ) async {
    try {
      final orders = await _repository.list(forceRefresh: true);
      emit(state.copyWith(
        status: PurchaseOrderListStatus.success,
        orders: orders,
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(
        status: PurchaseOrderListStatus.failure,
        error: e.message,
      ));
    }
  }
}
