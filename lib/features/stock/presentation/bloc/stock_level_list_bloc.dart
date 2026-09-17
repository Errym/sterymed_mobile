import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/api_exception.dart';
import '../../data/models/stock_level_data.dart';
import '../../data/repositories/stock_repository.dart';

part 'stock_level_list_event.dart';
part 'stock_level_list_state.dart';

class StockLevelListBloc
    extends Bloc<StockLevelListEvent, StockLevelListState> {
  final StockRepository _repository;

  StockLevelListBloc(this._repository) : super(const StockLevelListState()) {
    on<LoadStockLevels>(_onLoad);
    on<RefreshStockLevels>(_onRefresh);
    on<SearchStockLevels>(_onSearch);
  }

  Future<void> _onLoad(
    LoadStockLevels event,
    Emitter<StockLevelListState> emit,
  ) async {
    emit(state.copyWith(status: StockLevelStatus.loading, error: null));
    try {
      final levels = await _repository.listLevels();
      emit(state.copyWith(
        status: StockLevelStatus.success,
        levels: levels,
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(
        status: StockLevelStatus.failure,
        error: e.message,
      ));
    }
  }

  Future<void> _onRefresh(
    RefreshStockLevels event,
    Emitter<StockLevelListState> emit,
  ) async {
    try {
      final levels = await _repository.listLevels(search: state.query);
      emit(state.copyWith(status: StockLevelStatus.success, levels: levels));
    } on ApiException catch (e) {
      emit(state.copyWith(status: StockLevelStatus.failure, error: e.message));
    }
  }

  Future<void> _onSearch(
    SearchStockLevels event,
    Emitter<StockLevelListState> emit,
  ) async {
    emit(state.copyWith(query: event.query));
    try {
      final levels = await _repository.listLevels(search: event.query);
      emit(state.copyWith(status: StockLevelStatus.success, levels: levels));
    } on ApiException catch (e) {
      emit(state.copyWith(status: StockLevelStatus.failure, error: e.message));
    }
  }
}
