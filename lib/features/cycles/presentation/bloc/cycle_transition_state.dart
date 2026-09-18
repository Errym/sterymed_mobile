part of 'cycle_transition_bloc.dart';

enum CycleTransitionStatus { idle, loading, success, failure }

class CycleTransitionState extends Equatable {
  final CycleTransitionStatus status;
  final CycleData? cycle;
  final CycleReleaseData? release;
  final String? error;
  final String? errorCode;

  const CycleTransitionState({
    this.status = CycleTransitionStatus.idle,
    this.cycle,
    this.release,
    this.error,
    this.errorCode,
  });

  @override
  List<Object?> get props => [status, cycle, release, error, errorCode];
}
