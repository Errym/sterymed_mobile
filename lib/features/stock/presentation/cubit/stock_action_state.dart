part of 'stock_action_cubit.dart';

enum StockActionStatus { idle, loading, success, failure }

class StockActionState extends Equatable {
  final StockActionStatus status;
  final String? error;

  const StockActionState({
    this.status = StockActionStatus.idle,
    this.error,
  });

  @override
  List<Object?> get props => [status, error];
}
