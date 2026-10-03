part of 'patient_list_bloc.dart';

enum PatientListStatus { initial, loading, success, failure }

class PatientListState extends Equatable {
  final PatientListStatus status;
  final List<PatientData> patients;
  final String query;
  final String? error;

  /// The dossier just created, so the screen can show its new reference.
  final PatientData? lastCreated;

  const PatientListState({
    this.status = PatientListStatus.initial,
    this.patients = const [],
    this.query = '',
    this.error,
    this.lastCreated,
  });

  PatientListState copyWith({
    PatientListStatus? status,
    List<PatientData>? patients,
    String? query,
    String? error,
    PatientData? lastCreated,
  }) {
    return PatientListState(
      status: status ?? this.status,
      patients: patients ?? this.patients,
      query: query ?? this.query,
      error: error ?? this.error,
      lastCreated: lastCreated ?? this.lastCreated,
    );
  }

  @override
  List<Object?> get props => [status, patients, query, error, lastCreated];
}
