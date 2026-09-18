part of 'cycle_control_tests_bloc.dart';

enum ControlTestsStatus { initial, loading, success, failure }

class CycleControlTestsState extends Equatable {
  final ControlTestsStatus status;
  final List<ControlTestData> tests;
  final String? error;

  const CycleControlTestsState({
    this.status = ControlTestsStatus.initial,
    this.tests = const [],
    this.error,
  });

  CycleControlTestsState copyWith({
    ControlTestsStatus? status,
    List<ControlTestData>? tests,
    String? error,
  }) {
    return CycleControlTestsState(
      status: status ?? this.status,
      tests: tests ?? this.tests,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [status, tests, error];
}
