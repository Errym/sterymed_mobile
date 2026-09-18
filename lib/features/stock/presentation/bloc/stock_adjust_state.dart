part of 'stock_adjust_bloc.dart';

enum StockAdjustStatus { idle, loading, success, failure }

class StockAdjustState extends Equatable {
  final StockAdjustStatus status;
  final StockMovementData? movement;
  final String? error;

  const StockAdjustState({
    this.status = StockAdjustStatus.idle,
    this.movement,
    this.error,
  });

  StockAdjustState copyWith({
    StockAdjustStatus? status,
    StockMovementData? movement,
    String? error,
  }) {
    return StockAdjustState(
      status: status ?? this.status,
      movement: movement ?? this.movement,
      error: error,
    );
  }

  @override
  List<Object?> get props => [status, movement, error];
}
