part of 'evidence_search_bloc.dart';

abstract class EvidenceSearchEvent extends Equatable {
  const EvidenceSearchEvent();
  @override
  List<Object?> get props => [];
}

class SearchEvidence extends EvidenceSearchEvent {
  final String? patientReference;
  final int? cycleNumber;
  final String? batchNumber;
  final DateTime? from;
  final DateTime? to;

  const SearchEvidence({
    this.patientReference,
    this.cycleNumber,
    this.batchNumber,
    this.from,
    this.to,
  });

  @override
  List<Object?> get props =>
      [patientReference, cycleNumber, batchNumber, from, to];
}

class LoadMoreEvidence extends EvidenceSearchEvent {
  const LoadMoreEvidence();
}
