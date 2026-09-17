part of 'product_list_bloc.dart';

enum ProductListStatus { initial, loading, success, failure }

class ProductListState extends Equatable {
  final ProductListStatus status;
  final List<ProductData> products;
  final String query;
  final String? error;

  const ProductListState({
    this.status = ProductListStatus.initial,
    this.products = const [],
    this.query = '',
    this.error,
  });

  ProductListState copyWith({
    ProductListStatus? status,
    List<ProductData>? products,
    String? query,
    String? error,
  }) {
    return ProductListState(
      status: status ?? this.status,
      products: products ?? this.products,
      query: query ?? this.query,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [status, products, query, error];
}
