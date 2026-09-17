part of 'team_list_bloc.dart';

enum TeamStatus { initial, loading, success, failure }

class TeamListState extends Equatable {
  final TeamStatus status;
  final List<TeamMemberData> members;
  final String? roleFilter;
  final String? error;
  final bool inviteSuccess;

  const TeamListState({
    this.status = TeamStatus.initial,
    this.members = const [],
    this.roleFilter,
    this.error,
    this.inviteSuccess = false,
  });

  List<TeamMemberData> get filtered {
    if (roleFilter == null) return members;
    return members.where((m) => m.role == roleFilter).toList();
  }

  TeamListState copyWith({
    TeamStatus? status,
    List<TeamMemberData>? members,
    String? roleFilter,
    String? error,
    bool? inviteSuccess,
    bool clearFilter = false,
  }) {
    return TeamListState(
      status: status ?? this.status,
      members: members ?? this.members,
      roleFilter: clearFilter ? null : (roleFilter ?? this.roleFilter),
      error: error ?? this.error,
      inviteSuccess: inviteSuccess ?? this.inviteSuccess,
    );
  }

  @override
  List<Object?> get props =>
      [status, members, roleFilter, error, inviteSuccess];
}
