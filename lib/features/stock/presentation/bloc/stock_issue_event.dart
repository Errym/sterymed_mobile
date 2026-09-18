part of 'stock_issue_bloc.dart';

abstract class StockIssueEvent extends Equatable {
  const StockIssueEvent();
  @override
  List<Object?> get props => [];
}

class SubmitStockIssue extends StockIssueEvent {
  final String batchId;
  final String locationId;
  final int qty;
  final String? reason;
  const SubmitStockIssue({
    required this.batchId,
    required this.locationId,
    required this.qty,
    this.reason,
  });
  @override
  List<Object?> get props => [batchId, locationId, qty, reason];
}
