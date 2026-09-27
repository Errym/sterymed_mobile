part of 'prosthetic_case_list_bloc.dart';

class ProstheticCaseListFilters extends Equatable {
  final String? patientReference;
  final String? practitionerId;
  final String? laboratoryId;
  final String? workType;
  final String? status;
  final DateTime? from;
  final DateTime? to;

  const ProstheticCaseListFilters({
    this.patientReference,
    this.practitionerId,
    this.laboratoryId,
    this.workType,
    this.status,
    this.from,
    this.to,
  });

  bool get isEmpty =>
      patientReference == null &&
      practitionerId == null &&
      laboratoryId == null &&
      workType == null &&
      status == null &&
      from == null &&
      to == null;

  /// Explicit `clearX` flags rather than relying on `x ?? this.x`, since
  /// that pattern can never set a field back to null — needed for
  /// individual-filter removal (the "X" on an active filter chip).
  ProstheticCaseListFilters copyWith({
    String? patientReference,
    bool clearPatientReference = false,
    String? practitionerId,
    bool clearPractitionerId = false,
    String? laboratoryId,
    bool clearLaboratoryId = false,
    String? workType,
    bool clearWorkType = false,
    String? status,
    bool clearStatus = false,
    DateTime? from,
    bool clearFrom = false,
    DateTime? to,
    bool clearTo = false,
  }) {
    return ProstheticCaseListFilters(
      patientReference: clearPatientReference
          ? null
          : (patientReference ?? this.patientReference),
      practitionerId: clearPractitionerId
          ? null
          : (practitionerId ?? this.practitionerId),
      laboratoryId:
          clearLaboratoryId ? null : (laboratoryId ?? this.laboratoryId),
      workType: clearWorkType ? null : (workType ?? this.workType),
      status: clearStatus ? null : (status ?? this.status),
      from: clearFrom ? null : (from ?? this.from),
      to: clearTo ? null : (to ?? this.to),
    );
  }

  @override
  List<Object?> get props => [
        patientReference,
        practitionerId,
        laboratoryId,
        workType,
        status,
        from,
        to,
      ];
}

abstract class ProstheticCaseListEvent extends Equatable {
  const ProstheticCaseListEvent();
  @override
  List<Object?> get props => [];
}

class LoadProstheticCases extends ProstheticCaseListEvent {
  const LoadProstheticCases();
}

class FilterProstheticCases extends ProstheticCaseListEvent {
  final ProstheticCaseListFilters filters;
  const FilterProstheticCases(this.filters);
  @override
  List<Object?> get props => [filters];
}

class LoadMoreProstheticCases extends ProstheticCaseListEvent {
  const LoadMoreProstheticCases();
}
