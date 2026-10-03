part of 'stock_level_list_bloc.dart';

enum StockLevelStatus { initial, loading, success, failure }

/// The chip row above the list.
enum StockFilter { all, low, perishable, expired }

class StockLevelListState extends Equatable {
  final StockLevelStatus status;
  final List<StockLevelData> levels;
  final String query;
  final StockFilter filter;
  final String? error;

  const StockLevelListState({
    this.status = StockLevelStatus.initial,
    this.levels = const [],
    this.query = '',
    this.filter = StockFilter.all,
    this.error,
  });

  int get totalRefs => levels.map((l) => l.productId).toSet().length;
  int get lowCount => levels.where((l) => l.isLow).length;
  int get expiredCount => levels.where((l) => l.isExpired).length;
  int get nearExpiryCount => levels.where((l) => l.isNearExpiry).length;

  /// Rows that need nothing: not under the minimum, not expired.
  int get healthyCount => levels.where((l) => !l.isLow && !l.isExpired).length;

  /// Share of stock rows in good standing, 0-100. Null when there is no stock
  /// to judge (so the screen shows a dash, never a made-up 100%).
  int? get healthPercent =>
      levels.isEmpty ? null : (healthyCount * 100 / levels.length).round();

  bool _matchesFilter(StockLevelData l) {
    switch (filter) {
      case StockFilter.all:
        return true;
      case StockFilter.low:
        return l.isLow;
      case StockFilter.perishable:
        return l.expiryDate != null && !l.isExpired;
      case StockFilter.expired:
        return l.isExpired;
    }
  }

  int countFor(StockFilter f) {
    switch (f) {
      case StockFilter.all:
        return levels.length;
      case StockFilter.low:
        return lowCount;
      case StockFilter.perishable:
        return levels.where((l) => l.expiryDate != null && !l.isExpired).length;
      case StockFilter.expired:
        return expiredCount;
    }
  }

  /// Distinct products that are under their minimum: what to reorder first.
  int get urgentReorderCount =>
      levels.where((l) => l.isLow).map((l) => l.productId).toSet().length;

  /// How urgent a row is: expired first, then under the minimum, then close
  /// to its date limit, then fine.
  static int _criticity(StockLevelData l) {
    if (l.isExpired) return 0;
    if (l.isLow) return 1;
    if (l.isNearExpiry) return 2;
    return 3;
  }

  /// Rows after the chip and the search, most critical first (the order the
  /// screen announces as "Tri : criticité"). Ties keep a stable A-Z order.
  List<StockLevelData> get filtered {
    final byFilter = levels.where(_matchesFilter);
    final q = query.trim().toLowerCase();
    final rows = q.isEmpty
        ? byFilter.toList()
        : byFilter
            .where((l) =>
                l.productName.toLowerCase().contains(q) ||
                l.reference.toLowerCase().contains(q) ||
                (l.batchNumber?.toLowerCase().contains(q) ?? false))
            .toList();
    rows.sort((a, b) {
      final c = _criticity(a).compareTo(_criticity(b));
      if (c != 0) return c;
      return a.productName.toLowerCase().compareTo(b.productName.toLowerCase());
    });
    return rows;
  }

  StockLevelListState copyWith({
    StockLevelStatus? status,
    List<StockLevelData>? levels,
    String? query,
    StockFilter? filter,
    String? error,
  }) {
    return StockLevelListState(
      status: status ?? this.status,
      levels: levels ?? this.levels,
      query: query ?? this.query,
      filter: filter ?? this.filter,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [status, levels, query, filter, error];
}
