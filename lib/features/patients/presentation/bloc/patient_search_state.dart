part of 'patient_search_bloc.dart';

enum PatientSearchStatus { idle, loading, success, failure }

class PatientSearchState extends Equatable {
  final PatientSearchStatus status;
  final String query;
  final List<PatientData> results;
  final String? error;

  const PatientSearchState({
    this.status = PatientSearchStatus.idle,
    this.query = '',
    this.results = const [],
    this.error,
  });

  PatientSearchState copyWith({
    PatientSearchStatus? status,
    String? query,
    List<PatientData>? results,
    String? error,
  }) {
    return PatientSearchState(
      status: status ?? this.status,
      query: query ?? this.query,
      results: results ?? this.results,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [status, query, results, error];
}
