part of 'cycle_transition_bloc.dart';

enum CycleTransitionStatus { idle, loading, success, failure }

class CycleTransitionState extends Equatable {
  final CycleTransitionStatus status;
  final CycleData? cycle;
  final String? error;

  const CycleTransitionState({
    this.status = CycleTransitionStatus.idle,
    this.cycle,
    this.error,
  });

  @override
  List<Object?> get props => [status, cycle, error];
}