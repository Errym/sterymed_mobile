part of 'patient_list_bloc.dart';

abstract class PatientListEvent extends Equatable {
  const PatientListEvent();
  @override
  List<Object?> get props => [];
}

class LoadPatients extends PatientListEvent {
  const LoadPatients();
}

class SearchPatients extends PatientListEvent {
  final String query;
  const SearchPatients(this.query);
  @override
  List<Object?> get props => [query];
}

class CreatePatient extends PatientListEvent {
  final PatientCreateRequest request;
  const CreatePatient(this.request);
  @override
  List<Object?> get props => [request];
}

class UpdatePatient extends PatientListEvent {
  final String id;
  final PatientCreateRequest request;
  const UpdatePatient({required this.id, required this.request});
  @override
  List<Object?> get props => [id, request];
}

class DeletePatient extends PatientListEvent {
  final String id;
  const DeletePatient(this.id);
  @override
  List<Object?> get props => [id];
}
