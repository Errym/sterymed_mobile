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
    on<LoadMorePurchaseOrders>(_onLoadMore);
  }

  Future<void> _onLoad(
    LoadPurchaseOrders event,
    Emitter<PurchaseOrderListState> emit,
  ) async {
    emit(state.copyWith(status: PurchaseOrderListStatus.loading, error: null));
    try {
      final page = await _repository.list();
      emit(state.copyWith(
        status: PurchaseOrderListStatus.success,
        orders: page.items,
        nextCursor: page.nextCursor,
        clearNextCursor: page.nextCursor == null,
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
      final page = await _repository.list(forceRefresh: true);
      emit(state.copyWith(
        status: PurchaseOrderListStatus.success,
        orders: page.items,
        nextCursor: page.nextCursor,
        clearNextCursor: page.nextCursor == null,
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(
        status: PurchaseOrderListStatus.failure,
        error: e.message,
      ));
    }
  }

  Future<void> _onLoadMore(
    LoadMorePurchaseOrders event,
    Emitter<PurchaseOrderListState> emit,
  ) async {
    final cursor = state.nextCursor;
    if (cursor == null || state.isLoadingMore) return;
    emit(state.copyWith(isLoadingMore: true));
    try {
      final page = await _repository.loadMore(cursor);
      emit(state.copyWith(
        orders: [...state.orders, ...page.items],
        nextCursor: page.nextCursor,
        clearNextCursor: page.nextCursor == null,
        isLoadingMore: false,
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(isLoadingMore: false, error: e.message));
    }
  }
}
