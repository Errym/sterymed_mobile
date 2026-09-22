part of 'team_list_bloc.dart';

enum TeamStatus { initial, loading, success, failure }

class TeamListState extends Equatable {
  final TeamStatus status;
  final List<TeamMemberData> members;
  final String? roleFilter;
  final String searchQuery;
  final String? error;
  final bool inviteSuccess;

  const TeamListState({
    this.status = TeamStatus.initial,
    this.members = const [],
    this.roleFilter,
    this.searchQuery = '',
    this.error,
    this.inviteSuccess = false,
  });

  List<TeamMemberData> get filtered {
    var result = roleFilter == null
        ? members
        : members.where((m) => m.role == roleFilter).toList();
    final q = searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      result = result
          .where((m) =>
              m.name.toLowerCase().contains(q) ||
              m.email.toLowerCase().contains(q))
          .toList();
    }
    return result;
  }

  TeamListState copyWith({
    TeamStatus? status,
    List<TeamMemberData>? members,
    String? roleFilter,
    String? searchQuery,
    String? error,
    bool? inviteSuccess,
    bool clearFilter = false,
  }) {
    return TeamListState(
      status: status ?? this.status,
      members: members ?? this.members,
      roleFilter: clearFilter ? null : (roleFilter ?? this.roleFilter),
      searchQuery: searchQuery ?? this.searchQuery,
      error: error ?? this.error,
      inviteSuccess: inviteSuccess ?? this.inviteSuccess,
    );
  }

  @override
  List<Object?> get props =>
      [status, members, roleFilter, searchQuery, error, inviteSuccess];
}
