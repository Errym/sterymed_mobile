part of 'product_list_bloc.dart';

abstract class ProductListEvent extends Equatable {
  const ProductListEvent();
  @override
  List<Object?> get props => [];
}

class LoadProducts extends ProductListEvent {
  const LoadProducts();
}

class SearchProducts extends ProductListEvent {
  final String query;
  const SearchProducts(this.query);
  @override
  List<Object?> get props => [query];
}

/// Internal — dispatched by ProductListBloc itself after debouncing a
/// SearchProducts event, never by the UI directly.
class _ProductSearchDebounced extends ProductListEvent {
  final String query;
  const _ProductSearchDebounced(this.query);
  @override
  List<Object?> get props => [query];
}

class DeleteProduct extends ProductListEvent {
  final String id;
  const DeleteProduct(this.id);
  @override
  List<Object?> get props => [id];
}
