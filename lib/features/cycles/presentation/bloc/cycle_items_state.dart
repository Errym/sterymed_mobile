part of 'cycle_items_bloc.dart';

enum CycleItemsStatus { initial, loading, success, failure }

class CycleItemsState extends Equatable {
  final CycleItemsStatus status;
  final List<CycleItemData> items;
  final String? error;

  const CycleItemsState({
    this.status = CycleItemsStatus.initial,
    this.items = const [],
    this.error,
  });

  CycleItemsState copyWith({
    CycleItemsStatus? status,
    List<CycleItemData>? items,
    String? error,
  }) {
    return CycleItemsState(
      status: status ?? this.status,
      items: items ?? this.items,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [status, items, error];
}
