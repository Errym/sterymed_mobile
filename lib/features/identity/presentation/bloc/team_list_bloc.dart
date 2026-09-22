import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/api_exception.dart';
import '../../data/models/team_member_data.dart';
import '../../data/repositories/team_repository.dart';

part 'team_list_event.dart';
part 'team_list_state.dart';

class TeamListBloc extends Bloc<TeamListEvent, TeamListState> {
  final TeamRepository _repository;

  TeamListBloc(this._repository) : super(const TeamListState()) {
    on<LoadTeam>(_onLoad);
    on<FilterTeam>(_onFilter);
    on<SearchTeam>(_onSearch);
    on<InviteTeamMember>(_onInvite);
  }

  Future<void> _onLoad(LoadTeam event, Emitter<TeamListState> emit) async {
    emit(state.copyWith(status: TeamStatus.loading, error: null));
    try {
      final members = await _repository.list();
      emit(state.copyWith(status: TeamStatus.success, members: members));
    } on ApiException catch (e) {
      emit(state.copyWith(status: TeamStatus.failure, error: e.message));
    }
  }

  void _onFilter(FilterTeam event, Emitter<TeamListState> emit) {
    if (event.role == null) {
      emit(state.copyWith(clearFilter: true));
    } else {
      emit(state.copyWith(roleFilter: event.role));
    }
  }

  void _onSearch(SearchTeam event, Emitter<TeamListState> emit) {
    emit(state.copyWith(searchQuery: event.query));
  }

  Future<void> _onInvite(
    InviteTeamMember event,
    Emitter<TeamListState> emit,
  ) async {
    try {
      await _repository.invite(email: event.email, role: event.role);
      add(const LoadTeam());
      emit(state.copyWith(inviteSuccess: true));
    } on ApiException catch (e) {
      emit(state.copyWith(error: e.message, inviteSuccess: false));
    }
  }
}
