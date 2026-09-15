part of 'patient_search_bloc.dart';

abstract class PatientSearchEvent extends Equatable {
  const PatientSearchEvent();
  @override
  List<Object?> get props => [];
}

class PatientSearchQueryChanged extends PatientSearchEvent {
  final String query;
  const PatientSearchQueryChanged(this.query);
  @override
  List<Object> get props => [query];
}

class PatientSearchSubmitted extends PatientSearchEvent {
  final String query;
  const PatientSearchSubmitted(this.query);
  @override
  List<Object> get props => [query];
}

class PatientSearchCleared extends PatientSearchEvent {
  const PatientSearchCleared();
}
