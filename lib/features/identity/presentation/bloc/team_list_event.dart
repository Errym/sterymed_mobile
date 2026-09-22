part of 'team_list_bloc.dart';

abstract class TeamListEvent extends Equatable {
  const TeamListEvent();
  @override
  List<Object?> get props => [];
}

class LoadTeam extends TeamListEvent {
  const LoadTeam();
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

class InviteTeamMember extends TeamListEvent {
  final String email;
  final String role;
  const InviteTeamMember({required this.email, required this.role});
  @override
  List<Object?> get props => [email, role];
}
