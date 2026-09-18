part of 'stock_adjust_bloc.dart';

abstract class StockAdjustEvent extends Equatable {
  const StockAdjustEvent();
  @override
  List<Object?> get props => [];
}

class SubmitStockAdjust extends StockAdjustEvent {
  final String batchId;
  final String locationId;
  final int qty;
  final String reason;
  const SubmitStockAdjust({
    required this.batchId,
    required this.locationId,
    required this.qty,
    required this.reason,
  });
  @override
  List<Object?> get props => [batchId, locationId, qty, reason];
}
