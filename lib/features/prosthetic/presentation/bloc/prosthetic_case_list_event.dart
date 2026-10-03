part of 'prosthetic_case_list_bloc.dart';

/// The six user filters of brief §10 (patient, practitioner, laboratory, work
/// type, status, period) plus [scope], the dashboard card the list was opened
/// from. All of it lives in the bloc state, so it survives paging, refresh and
/// opening a case and coming back.
class ProstheticCaseListFilters extends Equatable {
  final String? patientReference;
  final String? practitionerId;
  final String? laboratoryId;
  final String? workType;
  final String? status;
  final DateTime? from;
  final DateTime? to;

  /// One of the server's dashboard scopes (`waiting_for_placement`,
  /// `payments_due`, ...). The server applies it, so the list total always
  /// equals the number on the card that opened it.
  final String? scope;

  const ProstheticCaseListFilters({
    this.patientReference,
    this.practitionerId,
    this.laboratoryId,
    this.workType,
    this.status,
    this.from,
    this.to,
    this.scope,
  });

  bool get isEmpty =>
      patientReference == null &&
      practitionerId == null &&
      laboratoryId == null &&
      workType == null &&
      status == null &&
      from == null &&
      to == null &&
      scope == null;

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
    String? scope,
    bool clearScope = false,
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
      scope: clearScope ? null : (scope ?? this.scope),
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
        scope,
      ];
}

abstract class ProstheticCaseListEvent extends Equatable {
  const ProstheticCaseListEvent();
  @override
  List<Object?> get props => [];
}

/// Re-fetch with the filters already in state (pull-to-refresh, retry, coming
/// back from a case that may have changed).
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
