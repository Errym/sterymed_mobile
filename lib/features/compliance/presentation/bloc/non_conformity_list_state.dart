part of 'non_conformity_list_bloc.dart';

enum NonConformityStatus { initial, loading, success, failure }

class NonConformityListState extends Equatable {
  final NonConformityStatus status;
  final List<NonConformityData> items;
  final String? statusFilter;
  final String? error;

  const NonConformityListState({
    this.status = NonConformityStatus.initial,
    this.items = const [],
    this.statusFilter,
    this.error,
  });

  NonConformityListState copyWith({
    NonConformityStatus? status,
    List<NonConformityData>? items,
    String? statusFilter,
    String? error,
    bool clearStatusFilter = false,
  }) {
    return NonConformityListState(
      status: status ?? this.status,
      items: items ?? this.items,
      statusFilter: clearStatusFilter
          ? null
          : (statusFilter ?? this.statusFilter),
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [status, items, statusFilter, error];
}
