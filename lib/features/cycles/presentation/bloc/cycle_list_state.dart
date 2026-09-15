part of 'cycle_list_bloc.dart';

enum CycleListStatus { initial, loading, success, failure }

class CycleListState extends Equatable {
  final CycleListStatus status;
  final List<CycleData> cycles;
  final String? selectedStatus;
  final String? error;

  const CycleListState({
    this.status = CycleListStatus.initial,
    this.cycles = const [],
    this.selectedStatus,
    this.error,
  });

  List<CycleData> get filtered => selectedStatus == null
      ? cycles
      : cycles.where((c) => c.status == selectedStatus).toList();

  CycleListState copyWith({
    CycleListStatus? status,
    List<CycleData>? cycles,
    String? selectedStatus,
    String? error,
  }) {
    return CycleListState(
      status: status ?? this.status,
      cycles: cycles ?? this.cycles,
      selectedStatus: selectedStatus ?? this.selectedStatus,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [status, cycles, selectedStatus, error];
}
