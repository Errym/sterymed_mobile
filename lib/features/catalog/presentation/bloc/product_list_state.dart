part of 'product_list_bloc.dart';

enum ProductListStatus { initial, loading, success, failure }

class ProductListState extends Equatable {
  final ProductListStatus status;
  final List<ProductData> products;
  final String query;

  /// Why the list itself could not be loaded (shown as an error page).
  final String? error;

  /// Why a single action (e.g. delete) failed while the list stays usable.
  final String? actionError;

  const ProductListState({
    this.status = ProductListStatus.initial,
    this.products = const [],
    this.query = '',
    this.error,
    this.actionError,
  });

  ProductListState copyWith({
    ProductListStatus? status,
    List<ProductData>? products,
    String? query,
    String? error,
    bool clearError = false,
    String? actionError,
    bool clearActionError = false,
  }) {
    return ProductListState(
      status: status ?? this.status,
      products: products ?? this.products,
      query: query ?? this.query,
      error: clearError ? null : (error ?? this.error),
      actionError: clearActionError ? null : (actionError ?? this.actionError),
    );
  }

  @override
  List<Object?> get props => [status, products, query, error, actionError];
}
