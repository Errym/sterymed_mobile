part of 'audit_list_bloc.dart';

enum AuditStatus { initial, loading, success, failure }

class AuditListState extends Equatable {
  final AuditStatus status;
  final List<AuditEventData> events;
  final String? actionFilter;
  final String? actorIdFilter;
  final String? actorLabelFilter;
  final String? subjectTypeFilter;
  final DateTime? fromFilter;
  final DateTime? toFilter;
  final String? error;
  final String? nextCursor;
  final bool isLoadingMore;
  final Map<String, String> seenActors;
  final Map<String, String> seenSubjectTypes;

  const AuditListState({
    this.status = AuditStatus.initial,
    this.events = const [],
    this.actionFilter,
    this.actorIdFilter,
    this.actorLabelFilter,
    this.subjectTypeFilter,
    this.fromFilter,
    this.toFilter,
    this.error,
    this.nextCursor,
    this.isLoadingMore = false,
    this.seenActors = const {},
    this.seenSubjectTypes = const {},
  });

  bool get hasMore => nextCursor != null;

  bool get hasAdvancedFilters =>
      actorIdFilter != null || subjectTypeFilter != null ||
      fromFilter != null || toFilter != null;

  /// Distinct actors ever seen this session — the only way to build an
  /// actor picker, since the backend has no member-list endpoint
  /// (docs/BACKEND_BUGS.md#BUG-011). Accumulated across loads rather than
  /// read off the current (possibly filtered) `events`, so applying one
  /// filter doesn't shrink the options available for the next one.
  List<MapEntry<String, String>> get knownActors => seenActors.entries.toList();

  /// Distinct subject types ever seen this session — same reasoning as
  /// [knownActors]: there's no backend enum/list endpoint for this.
  List<MapEntry<String, String>> get knownSubjectTypes =>
      seenSubjectTypes.entries.toList();

  AuditListState copyWith({
    AuditStatus? status,
    List<AuditEventData>? events,
    String? actionFilter,
    bool clearActionFilter = false,
    String? actorIdFilter,
    String? actorLabelFilter,
    bool clearActorFilter = false,
    String? subjectTypeFilter,
    bool clearSubjectTypeFilter = false,
    DateTime? fromFilter,
    bool clearFromFilter = false,
    DateTime? toFilter,
    bool clearToFilter = false,
    String? error,
    String? nextCursor,
    bool clearNextCursor = false,
    bool? isLoadingMore,
    Map<String, String>? seenActors,
    Map<String, String>? seenSubjectTypes,
  }) {
    return AuditListState(
      status: status ?? this.status,
      events: events ?? this.events,
      actionFilter:
          clearActionFilter ? null : (actionFilter ?? this.actionFilter),
      actorIdFilter:
          clearActorFilter ? null : (actorIdFilter ?? this.actorIdFilter),
      actorLabelFilter: clearActorFilter
          ? null
          : (actorLabelFilter ?? this.actorLabelFilter),
      subjectTypeFilter: clearSubjectTypeFilter
          ? null
          : (subjectTypeFilter ?? this.subjectTypeFilter),
      fromFilter: clearFromFilter ? null : (fromFilter ?? this.fromFilter),
      toFilter: clearToFilter ? null : (toFilter ?? this.toFilter),
      error: error ?? this.error,
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      seenActors: seenActors ?? this.seenActors,
      seenSubjectTypes: seenSubjectTypes ?? this.seenSubjectTypes,
    );
  }

  @override
  List<Object?> get props => [
        status,
        events,
        actionFilter,
        actorIdFilter,
        subjectTypeFilter,
        fromFilter,
        toFilter,
        error,
        nextCursor,
        isLoadingMore,
      ];
}
