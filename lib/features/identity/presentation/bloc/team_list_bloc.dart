import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/utils/error_message.dart';
import '../../data/models/open_invitation.dart';
import '../../data/models/team_member_data.dart';
import '../../data/repositories/team_repository.dart';

part 'team_list_event.dart';
part 'team_list_state.dart';

class TeamListBloc extends Bloc<TeamListEvent, TeamListState> {
  final TeamRepository _repository;

  /// Whether the signed-in user may see and manage invitations. The server
  /// enforces it too; this only avoids a request that would be refused.
  final bool loadInvitations;

  TeamListBloc(this._repository, {this.loadInvitations = false})
    : super(const TeamListState()) {
    on<LoadTeam>(_onLoad);
    on<FilterTeam>(_onFilter);
    on<SearchTeam>(_onSearch);
    on<ResendInvitation>(_onResend);
    on<RevokeInvitation>(_onRevoke);
    on<ClearTeamNotice>((e, emit) => emit(state.copyWith(clearNotice: true)));
  }

  Future<void> _onLoad(LoadTeam event, Emitter<TeamListState> emit) async {
    emit(state.copyWith(status: TeamStatus.loading, clearError: true));
    try {
      final members = await _repository.list(forceRefresh: true);
      emit(state.copyWith(status: TeamStatus.success, members: members));
    } on ApiException catch (e) {
      emit(state.copyWith(status: TeamStatus.failure, error: e.message));
      return;
    }
    if (loadInvitations) await _refreshInvitations(emit);
  }

  /// Invitations are secondary to the member list: if they cannot be loaded the
  /// members still show, and the failure is reported instead of hidden.
  Future<void> _refreshInvitations(Emitter<TeamListState> emit) async {
    try {
      final open = await _repository.invitations();
      emit(state.copyWith(invitations: open, clearInvitationsError: true));
    } catch (e) {
      emit(state.copyWith(invitationsError: ErrorMessage.from(e)));
    }
  }

  Future<void> _onResend(
    ResendInvitation event,
    Emitter<TeamListState> emit,
  ) async {
    try {
      await _repository.resendInvitation(event.id);
      emit(state.copyWith(actionMessage: 'Invitation renvoyée.'));
      await _refreshInvitations(emit);
    } catch (e) {
      emit(state.copyWith(actionError: ErrorMessage.from(e)));
    }
  }

  Future<void> _onRevoke(
    RevokeInvitation event,
    Emitter<TeamListState> emit,
  ) async {
    try {
      await _repository.revokeInvitation(event.id);
      emit(state.copyWith(actionMessage: 'Invitation annulée.'));
      await _refreshInvitations(emit);
    } catch (e) {
      emit(state.copyWith(actionError: ErrorMessage.from(e)));
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
}
