part of 'cycle_create_bloc.dart';

enum CycleCreateStatus { idle, loading, success, failure }

class CycleCreateState extends Equatable {
  final CycleCreateStatus status;
  final CycleData? cycle;
  final String? error;

  const CycleCreateState({
    this.status = CycleCreateStatus.idle,
    this.cycle,
    this.error,
  });

  CycleCreateState copyWith({
    CycleCreateStatus? status,
    CycleData? cycle,
    String? error,
  }) {
    return CycleCreateState(
      status: status ?? this.status,
      cycle: cycle ?? this.cycle,
      error: error,
    );
  }

  @override
  List<Object?> get props => [status, cycle, error];
}
