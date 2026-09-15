part of 'cycle_detail_bloc.dart';

abstract class CycleDetailEvent extends Equatable {
  const CycleDetailEvent();
  @override
  List<Object?> get props => [];
}

class LoadCycleDetail extends CycleDetailEvent {
  final String cycleId;
  const LoadCycleDetail(this.cycleId);
  @override
  List<Object> get props => [cycleId];
}

class RefreshCycleDetail extends CycleDetailEvent {
  final String cycleId;
  const RefreshCycleDetail(this.cycleId);
  @override
  List<Object> get props => [cycleId];
}
