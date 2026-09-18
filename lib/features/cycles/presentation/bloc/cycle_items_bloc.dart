import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/api_exception.dart';
import '../../data/models/cycle_item_data.dart';
import '../../data/repositories/cycle_repository.dart';

part 'cycle_items_event.dart';
part 'cycle_items_state.dart';

class CycleItemsBloc extends Bloc<CycleItemsEvent, CycleItemsState> {
  final CycleRepository _repository;
  final String cycleId;

  CycleItemsBloc(this._repository, this.cycleId)
      : super(const CycleItemsState()) {
    on<LoadCycleItems>(_onLoad);
    on<AddCycleItem>(_onAdd);
    on<DeleteCycleItem>(_onDelete);
  }

  Future<void> _onLoad(
    LoadCycleItems event,
    Emitter<CycleItemsState> emit,
  ) async {
    emit(state.copyWith(status: CycleItemsStatus.loading, error: null));
    try {
      final items = await _repository.listItems(cycleId);
      emit(CycleItemsState(
        status: CycleItemsStatus.success,
        items: items,
      ));
    } on ApiException catch (e) {
      emit(CycleItemsState(
        status: CycleItemsStatus.failure,
        error: e.message,
      ));
    }
  }

  Future<void> _onAdd(
    AddCycleItem event,
    Emitter<CycleItemsState> emit,
  ) async {
    try {
      await _repository.addItem(cycleId, {
        'description': event.description,
        if (event.batchId != null) 'batch_id': event.batchId,
      });
      add(const LoadCycleItems());
    } on ApiException catch (e) {
      emit(state.copyWith(error: e.message));
    }
  }

  Future<void> _onDelete(
    DeleteCycleItem event,
    Emitter<CycleItemsState> emit,
  ) async {
    try {
      await _repository.deleteItem(cycleId, event.itemId);
      add(const LoadCycleItems());
    } on ApiException catch (e) {
      emit(state.copyWith(error: e.message));
    }
  }
}
