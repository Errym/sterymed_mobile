part of 'patient_list_bloc.dart';

enum PatientListStatus { initial, loading, success, failure }

class PatientListState extends Equatable {
  final PatientListStatus status;
  final List<PatientData> patients;
  final String query;
  final String? error;

  const PatientListState({
    this.status = PatientListStatus.initial,
    this.patients = const [],
    this.query = '',
    this.error,
  });

  PatientListState copyWith({
    PatientListStatus? status,
    List<PatientData>? patients,
    String? query,
    String? error,
  }) {
    return PatientListState(
      status: status ?? this.status,
      patients: patients ?? this.patients,
      query: query ?? this.query,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [status, patients, query, error];
}
