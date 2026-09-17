part of 'non_conformity_list_bloc.dart';

abstract class NonConformityListEvent extends Equatable {
  const NonConformityListEvent();
  @override
  List<Object?> get props => [];
}

class LoadNonConformities extends NonConformityListEvent {
  const LoadNonConformities();
}

class FilterNonConformities extends NonConformityListEvent {
  final String? status;
  const FilterNonConformities(this.status);
  @override
  List<Object?> get props => [status];
}
