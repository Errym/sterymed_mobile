part of 'team_list_bloc.dart';

enum TeamStatus { initial, loading, success, failure }

class TeamListState extends Equatable {
  final TeamStatus status;
  final List<TeamMemberData> members;
  final List<OpenInvitation> invitations;
  final String? roleFilter;
  final String searchQuery;
  final String? error;

  /// Why the invitations could not be loaded (the members still show).
  final String? invitationsError;

  /// One-shot feedback for an action (resend/cancel), shown once then cleared.
  final String? actionMessage;
  final String? actionError;

  const TeamListState({
    this.status = TeamStatus.initial,
    this.members = const [],
    this.invitations = const [],
    this.roleFilter,
    this.searchQuery = '',
    this.error,
    this.invitationsError,
    this.actionMessage,
    this.actionError,
  });

  List<TeamMemberData> get filtered {
    var result = roleFilter == null
        ? members
        : members.where((m) => m.role == roleFilter).toList();
    final q = searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      result = result
          .where(
            (m) =>
                m.name.toLowerCase().contains(q) ||
                m.email.toLowerCase().contains(q),
          )
          .toList();
    }
    return result;
  }

  TeamListState copyWith({
    TeamStatus? status,
    List<TeamMemberData>? members,
    List<OpenInvitation>? invitations,
    String? roleFilter,
    String? searchQuery,
    String? error,
    bool clearError = false,
    bool clearFilter = false,
    String? invitationsError,
    bool clearInvitationsError = false,
    String? actionMessage,
    String? actionError,
    bool clearNotice = false,
  }) {
    return TeamListState(
      status: status ?? this.status,
      members: members ?? this.members,
      invitations: invitations ?? this.invitations,
      roleFilter: clearFilter ? null : (roleFilter ?? this.roleFilter),
      searchQuery: searchQuery ?? this.searchQuery,
      error: clearError ? null : (error ?? this.error),
      invitationsError: clearInvitationsError
          ? null
          : (invitationsError ?? this.invitationsError),
      actionMessage: clearNotice ? null : (actionMessage ?? this.actionMessage),
      actionError: clearNotice ? null : (actionError ?? this.actionError),
    );
  }

  @override
  List<Object?> get props => [
    status,
    members,
    invitations,
    roleFilter,
    searchQuery,
    error,
    invitationsError,
    actionMessage,
    actionError,
  ];
}
