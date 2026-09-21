part of 'supplier_list_bloc.dart';

abstract class SupplierListEvent extends Equatable {
  const SupplierListEvent();
  @override
  List<Object?> get props => [];
}

class LoadSuppliers extends SupplierListEvent {
  const LoadSuppliers();
}
