part of 'cycle_list_bloc.dart';

abstract class CycleListEvent extends Equatable {
  const CycleListEvent();
  @override
  List<Object?> get props => [];
}

class LoadCycles extends CycleListEvent {
  const LoadCycles();
}

class RefreshCycles extends CycleListEvent {
  const RefreshCycles();
}

class FilterCycles extends CycleListEvent {
  final String? status;
  const FilterCycles(this.status);
  @override
  List<Object?> get props => [status];
}
