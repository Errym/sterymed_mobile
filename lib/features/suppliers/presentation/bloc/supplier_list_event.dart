part of 'supplier_list_bloc.dart';

abstract class SupplierListEvent extends Equatable {
  const SupplierListEvent();
  @override
  List<Object?> get props => [];
}

class LoadSuppliers extends SupplierListEvent {
  const LoadSuppliers();
}

class CreateSupplier extends SupplierListEvent {
  final String name;
  final String? email;
  final String? phone;
  final String? address;
  const CreateSupplier({
    required this.name,
    this.email,
    this.phone,
    this.address,
  });
  @override
  List<Object?> get props => [name];
}
