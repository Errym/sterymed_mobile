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

  /// Bumped by every load. A response that arrives after a newer request was
  /// started (typing faster than the network answers) is dropped, so an old
  /// query can never overwrite the list for the current one.
  int _generation = 0;

  ProductListBloc(this._repository) : super(const ProductListState()) {
    on<LoadProducts>(_onLoad);
    on<SearchProducts>(_onSearchQueryChanged);
    on<_ProductSearchDebounced>(_onSearch);
    on<DeleteProduct>(_onDelete);
    on<ClearProductActionError>(
      (e, emit) => emit(state.copyWith(clearActionError: true)),
    );
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

  /// Refresh and reload always honour the current search box and always bypass
  /// the cache, so they never show an unfiltered or stale list.
  Future<void> _onLoad(LoadProducts e, Emitter<ProductListState> emit) =>
      _load(emit, query: state.query, forceRefresh: true);

  Future<void> _onSearch(
    _ProductSearchDebounced e,
    Emitter<ProductListState> emit,
  ) => _load(emit, query: e.query, forceRefresh: false);

  Future<void> _load(
    Emitter<ProductListState> emit, {
    required String query,
    required bool forceRefresh,
  }) async {
    final generation = ++_generation;
    emit(state.copyWith(status: ProductListStatus.loading, clearError: true));
    try {
      final list = await _repository.list(
        search: query.trim().isEmpty ? null : query,
        forceRefresh: forceRefresh,
      );
      if (generation != _generation) return;
      emit(state.copyWith(status: ProductListStatus.success, products: list));
    } on ApiException catch (ex) {
      if (generation != _generation) return;
      emit(
        state.copyWith(status: ProductListStatus.failure, error: ex.message),
      );
    }
  }

  Future<void> _onDelete(
    DeleteProduct e,
    Emitter<ProductListState> emit,
  ) async {
    try {
      await _repository.destroy(e.id);
      add(const LoadProducts());
    } on ApiException catch (ex) {
      // The list is still valid: report the failure without replacing it by an
      // error page, so the user sees why the product is still there.
      emit(state.copyWith(actionError: ex.message));
    }
  }

  @override
  Future<void> close() {
    _debouncer.dispose();
    return super.close();
  }
}
