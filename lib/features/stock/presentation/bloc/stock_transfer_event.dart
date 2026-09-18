part of 'stock_transfer_bloc.dart';

abstract class StockTransferEvent extends Equatable {
  const StockTransferEvent();
  @override
  List<Object?> get props => [];
}

class SubmitStockTransfer extends StockTransferEvent {
  final String batchId;
  final String fromLocationId;
  final String toLocationId;
  final int qty;
  final String? reason;
  const SubmitStockTransfer({
    required this.batchId,
    required this.fromLocationId,
    required this.toLocationId,
    required this.qty,
    this.reason,
  });
  @override
  List<Object?> get props =>
      [batchId, fromLocationId, toLocationId, qty, reason];
}
