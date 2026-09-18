part of 'stock_transfer_bloc.dart';

enum StockTransferStatus { idle, loading, success, failure }

class StockTransferState extends Equatable {
  final StockTransferStatus status;
  final StockMovementData? movement;
  final String? error;

  const StockTransferState({
    this.status = StockTransferStatus.idle,
    this.movement,
    this.error,
  });

  StockTransferState copyWith({
    StockTransferStatus? status,
    StockMovementData? movement,
    String? error,
  }) {
    return StockTransferState(
      status: status ?? this.status,
      movement: movement ?? this.movement,
      error: error,
    );
  }

  @override
  List<Object?> get props => [status, movement, error];
}
