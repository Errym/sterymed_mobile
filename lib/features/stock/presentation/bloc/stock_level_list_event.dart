part of 'stock_level_list_bloc.dart';

abstract class StockLevelListEvent extends Equatable {
  const StockLevelListEvent();
  @override
  List<Object?> get props => [];
}

class LoadStockLevels extends StockLevelListEvent {
  const LoadStockLevels();
}

class RefreshStockLevels extends StockLevelListEvent {
  const RefreshStockLevels();
}

class SearchStockLevels extends StockLevelListEvent {
  final String query;
  const SearchStockLevels(this.query);
  @override
  List<Object?> get props => [query];
}
