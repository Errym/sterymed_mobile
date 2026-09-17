part of 'purchase_order_list_bloc.dart';

enum PurchaseOrderListStatus { initial, loading, success, failure }

class PurchaseOrderListState extends Equatable {
  final PurchaseOrderListStatus status;
  final List<PurchaseOrderData> orders;
  final String? error;

  const PurchaseOrderListState({
    this.status = PurchaseOrderListStatus.initial,
    this.orders = const [],
    this.error,
  });

  PurchaseOrderListState copyWith({
    PurchaseOrderListStatus? status,
    List<PurchaseOrderData>? orders,
    String? error,
  }) {
    return PurchaseOrderListState(
      status: status ?? this.status,
      orders: orders ?? this.orders,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [status, orders, error];
}
