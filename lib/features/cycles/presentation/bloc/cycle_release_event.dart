part of 'cycle_release_bloc.dart';

abstract class CycleReleaseEvent extends Equatable {
  const CycleReleaseEvent();
  @override
  List<Object?> get props => [];
}

class SubmitCycleRelease extends CycleReleaseEvent {
  final String cycleId;
  final String decision; // 'compliant' | 'rejected'
  final String? reason;
  const SubmitCycleRelease({
    required this.cycleId,
    required this.decision,
    this.reason,
  });
  @override
  List<Object?> get props => [cycleId, decision, reason];
}
