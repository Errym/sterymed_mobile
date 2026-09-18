part of 'cycle_items_bloc.dart';

abstract class CycleItemsEvent extends Equatable {
  const CycleItemsEvent();
  @override
  List<Object?> get props => [];
}

class LoadCycleItems extends CycleItemsEvent {
  const LoadCycleItems();
}

class AddCycleItem extends CycleItemsEvent {
  final String description;
  final String? batchId;
  const AddCycleItem({required this.description, this.batchId});
  @override
  List<Object?> get props => [description, batchId];
}

class DeleteCycleItem extends CycleItemsEvent {
  final String itemId;
  const DeleteCycleItem(this.itemId);
  @override
  List<Object?> get props => [itemId];
}
