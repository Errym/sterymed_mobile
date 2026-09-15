part of 'cycle_transition_bloc.dart';

abstract class CycleTransitionEvent extends Equatable {
  const CycleTransitionEvent();
  @override
  List<Object?> get props => [];
}

class StartCycle extends CycleTransitionEvent {
  final String cycleId;
  const StartCycle(this.cycleId);
  @override
  List<Object> get props => [cycleId];
}

class CompleteCycle extends CycleTransitionEvent {
  final String cycleId;
  const CompleteCycle(this.cycleId);
  @override
  List<Object> get props => [cycleId];
}

class SubmitCycleForRelease extends CycleTransitionEvent {
  final String cycleId;
  const SubmitCycleForRelease(this.cycleId);
  @override
  List<Object> get props => [cycleId];
}
