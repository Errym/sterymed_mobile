part of 'stock_level_list_bloc.dart';

enum StockLevelStatus { initial, loading, success, failure }

class StockLevelListState extends Equatable {
  final StockLevelStatus status;
  final List<StockLevelData> levels;
  final String query;
  final String? error;

  const StockLevelListState({
    this.status = StockLevelStatus.initial,
    this.levels = const [],
    this.query = '',
    this.error,
  });

  int get totalRefs => levels.map((l) => l.productId).toSet().length;
  int get lowCount => levels.where((l) => l.isLow).length;
  int get expiredCount => levels.where((l) => l.isExpired).length;
  int get nearExpiryCount => levels.where((l) => l.isNearExpiry).length;

  List<StockLevelData> get filtered {
    if (query.trim().isEmpty) return levels;
    final q = query.trim().toLowerCase();
    return levels
        .where((l) =>
            l.productName.toLowerCase().contains(q) ||
            l.reference.toLowerCase().contains(q) ||
            (l.batchNumber?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  StockLevelListState copyWith({
    StockLevelStatus? status,
    List<StockLevelData>? levels,
    String? query,
    String? error,
  }) {
    return StockLevelListState(
      status: status ?? this.status,
      levels: levels ?? this.levels,
      query: query ?? this.query,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [status, levels, query, error];
}
