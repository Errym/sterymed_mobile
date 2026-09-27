part of 'evidence_search_bloc.dart';

enum EvidenceSearchStatus { initial, loading, success, failure }

class EvidenceSearchState extends Equatable {
  final EvidenceSearchStatus status;
  final List<EvidenceSearchResultData> results;
  final String? patientReference;
  final int? cycleNumber;
  final String? batchNumber;
  final DateTime? from;
  final DateTime? to;
  final String? error;
  final String? nextCursor;
  final bool isLoadingMore;
  final bool hasSearched;

  const EvidenceSearchState({
    this.status = EvidenceSearchStatus.initial,
    this.results = const [],
    this.patientReference,
    this.cycleNumber,
    this.batchNumber,
    this.from,
    this.to,
    this.error,
    this.nextCursor,
    this.isLoadingMore = false,
    this.hasSearched = false,
  });

  bool get hasMore => nextCursor != null;

  bool get hasFilters =>
      patientReference != null ||
      cycleNumber != null ||
      batchNumber != null ||
      from != null ||
      to != null;

  EvidenceSearchState copyWith({
    EvidenceSearchStatus? status,
    List<EvidenceSearchResultData>? results,
    String? patientReference,
    bool clearPatientReference = false,
    int? cycleNumber,
    bool clearCycleNumber = false,
    String? batchNumber,
    bool clearBatchNumber = false,
    DateTime? from,
    bool clearFrom = false,
    DateTime? to,
    bool clearTo = false,
    String? error,
    String? nextCursor,
    bool clearNextCursor = false,
    bool? isLoadingMore,
    bool? hasSearched,
  }) {
    return EvidenceSearchState(
      status: status ?? this.status,
      results: results ?? this.results,
      patientReference: clearPatientReference
          ? null
          : (patientReference ?? this.patientReference),
      cycleNumber:
          clearCycleNumber ? null : (cycleNumber ?? this.cycleNumber),
      batchNumber:
          clearBatchNumber ? null : (batchNumber ?? this.batchNumber),
      from: clearFrom ? null : (from ?? this.from),
      to: clearTo ? null : (to ?? this.to),
      error: error,
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasSearched: hasSearched ?? this.hasSearched,
    );
  }

  @override
  List<Object?> get props => [
        status,
        results,
        patientReference,
        cycleNumber,
        batchNumber,
        from,
        to,
        error,
        nextCursor,
        isLoadingMore,
        hasSearched,
      ];
}
