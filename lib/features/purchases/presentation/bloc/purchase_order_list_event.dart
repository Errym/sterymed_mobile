part of 'purchase_order_list_bloc.dart';

abstract class PurchaseOrderListEvent extends Equatable {
  const PurchaseOrderListEvent();
  @override
  List<Object?> get props => [];
}

class LoadPurchaseOrders extends PurchaseOrderListEvent {
  const LoadPurchaseOrders();
}

class RefreshPurchaseOrders extends PurchaseOrderListEvent {
  const RefreshPurchaseOrders();
}
