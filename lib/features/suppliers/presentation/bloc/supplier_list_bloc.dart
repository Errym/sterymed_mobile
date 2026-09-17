import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/api_exception.dart';
import '../../data/models/supplier_data.dart';
import '../../data/repositories/supplier_repository.dart';

part 'supplier_list_event.dart';
part 'supplier_list_state.dart';

class SupplierListBloc extends Bloc<SupplierListEvent, SupplierListState> {
  final SupplierRepository _repository;

  SupplierListBloc(this._repository) : super(const SupplierListState()) {
    on<LoadSuppliers>(_onLoad);
    on<CreateSupplier>(_onCreate);
  }

  Future<void> _onLoad(LoadSuppliers e, Emitter<SupplierListState> emit) async {
    emit(state.copyWith(status: SupplierListStatus.loading, error: null));
    try {
      final list = await _repository.list();
      emit(state.copyWith(status: SupplierListStatus.success, suppliers: list));
    } on ApiException catch (ex) {
      emit(state.copyWith(status: SupplierListStatus.failure, error: ex.message));
    }
  }

  Future<void> _onCreate(CreateSupplier e, Emitter<SupplierListState> emit) async {
    try {
      await _repository.create(
        name: e.name,
        email: e.email,
        phone: e.phone,
        address: e.address,
      );
      add(const LoadSuppliers());
    } on ApiException catch (ex) {
      emit(state.copyWith(error: ex.message));
    }
  }
}
