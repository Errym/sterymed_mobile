part of 'team_list_bloc.dart';

abstract class TeamListEvent extends Equatable {
  const TeamListEvent();
  @override
  List<Object?> get props => [];
}

class LoadTeam extends TeamListEvent {
  const LoadTeam();
}

/// Send an open invitation again (fresh link, fresh 7 days).
class ResendInvitation extends TeamListEvent {
  final String id;
  const ResendInvitation(this.id);
  @override
  List<Object?> get props => [id];
}

/// Cancel an open invitation.
class RevokeInvitation extends TeamListEvent {
  final String id;
  const RevokeInvitation(this.id);
  @override
  List<Object?> get props => [id];
}

/// Sent by the screen once it has shown [TeamListState.actionMessage] or
/// [TeamListState.actionError].
class ClearTeamNotice extends TeamListEvent {
  const ClearTeamNotice();
}

class FilterTeam extends TeamListEvent {
  final String? role;
  const FilterTeam(this.role);
  @override
  List<Object?> get props => [role];
}

class SearchTeam extends TeamListEvent {
  final String query;
  const SearchTeam(this.query);
  @override
  List<Object?> get props => [query];
}
