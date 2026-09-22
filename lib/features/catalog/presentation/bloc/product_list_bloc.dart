import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/utils/debouncer.dart';
import '../../data/models/product_data.dart';
import '../../data/repositories/product_repository.dart';

part 'product_list_event.dart';
part 'product_list_state.dart';

class ProductListBloc extends Bloc<ProductListEvent, ProductListState> {
  final ProductRepository _repository;
  final _debouncer = Debouncer(delay: const Duration(milliseconds: 300));

  ProductListBloc(this._repository) : super(const ProductListState()) {
    on<LoadProducts>(_onLoad);
    on<SearchProducts>(_onSearchQueryChanged);
    on<_ProductSearchDebounced>(_onSearch);
    on<DeleteProduct>(_onDelete);
  }

  void _onSearchQueryChanged(
    SearchProducts e,
    Emitter<ProductListState> emit,
  ) {
    emit(state.copyWith(query: e.query));
    _debouncer.run(() {
      if (!isClosed) add(_ProductSearchDebounced(e.query));
    });
  }

  Future<void> _onLoad(LoadProducts e, Emitter<ProductListState> emit) async {
    emit(state.copyWith(status: ProductListStatus.loading, error: null));
    try {
      final list = await _repository.list();
      emit(state.copyWith(status: ProductListStatus.success, products: list));
    } on ApiException catch (ex) {
      emit(
          state.copyWith(status: ProductListStatus.failure, error: ex.message));
    }
  }

  Future<void> _onSearch(
      _ProductSearchDebounced e, Emitter<ProductListState> emit) async {
    emit(state.copyWith(status: ProductListStatus.loading, error: null));
    try {
      final list = await _repository.list(search: e.query);
      emit(state.copyWith(status: ProductListStatus.success, products: list));
    } on ApiException catch (ex) {
      emit(
          state.copyWith(status: ProductListStatus.failure, error: ex.message));
    }
  }

  Future<void> _onDelete(
      DeleteProduct e, Emitter<ProductListState> emit) async {
    try {
      await _repository.destroy(e.id);
      add(const LoadProducts());
    } on ApiException catch (ex) {
      emit(state.copyWith(error: ex.message));
    }
  }

  @override
  Future<void> close() {
    _debouncer.dispose();
    return super.close();
  }
}
