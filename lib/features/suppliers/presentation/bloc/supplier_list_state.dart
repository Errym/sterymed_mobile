part of 'supplier_list_bloc.dart';

enum SupplierListStatus { initial, loading, success, failure }

class SupplierListState extends Equatable {
  final SupplierListStatus status;
  final List<SupplierData> suppliers;
  final String? error;

  const SupplierListState({
    this.status = SupplierListStatus.initial,
    this.suppliers = const [],
    this.error,
  });

  SupplierListState copyWith({
    SupplierListStatus? status,
    List<SupplierData>? suppliers,
    String? error,
  }) {
    return SupplierListState(
      status: status ?? this.status,
      suppliers: suppliers ?? this.suppliers,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [status, suppliers, error];
}
