part of 'stock_issue_bloc.dart';

enum StockIssueStatus { idle, loading, success, failure }

class StockIssueState extends Equatable {
  final StockIssueStatus status;
  final StockMovementData? movement;
  final String? error;

  const StockIssueState({
    this.status = StockIssueStatus.idle,
    this.movement,
    this.error,
  });

  StockIssueState copyWith({
    StockIssueStatus? status,
    StockMovementData? movement,
    String? error,
  }) {
    return StockIssueState(
      status: status ?? this.status,
      movement: movement ?? this.movement,
      error: error,
    );
  }

  @override
  List<Object?> get props => [status, movement, error];
}
