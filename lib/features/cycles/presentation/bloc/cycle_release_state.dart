part of 'cycle_release_bloc.dart';

enum CycleReleaseStatus { idle, loading, success, failure }

class CycleReleaseState extends Equatable {
  final CycleReleaseStatus status;
  final CycleReleaseData? release;
  final String? error;

  const CycleReleaseState({
    this.status = CycleReleaseStatus.idle,
    this.release,
    this.error,
  });

  CycleReleaseState copyWith({
    CycleReleaseStatus? status,
    CycleReleaseData? release,
    String? error,
  }) {
    return CycleReleaseState(
      status: status ?? this.status,
      release: release ?? this.release,
      error: error,
    );
  }

  @override
  List<Object?> get props => [status, release, error];
}
