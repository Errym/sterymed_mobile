part of 'purchase_order_list_bloc.dart';

enum PurchaseOrderListStatus { initial, loading, success, failure }

class PurchaseOrderListState extends Equatable {
  final PurchaseOrderListStatus status;
  final List<PurchaseOrderData> orders;
  final String? error;
  final String? nextCursor;
  final bool isLoadingMore;

  const PurchaseOrderListState({
    this.status = PurchaseOrderListStatus.initial,
    this.orders = const [],
    this.error,
    this.nextCursor,
    this.isLoadingMore = false,
  });

  bool get hasMore => nextCursor != null;

  PurchaseOrderListState copyWith({
    PurchaseOrderListStatus? status,
    List<PurchaseOrderData>? orders,
    String? error,
    String? nextCursor,
    bool clearNextCursor = false,
    bool? isLoadingMore,
  }) {
    return PurchaseOrderListState(
      status: status ?? this.status,
      orders: orders ?? this.orders,
      error: error ?? this.error,
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props =>
      [status, orders, error, nextCursor, isLoadingMore];
}
