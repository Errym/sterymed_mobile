import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/errors/api_exception.dart';
import 'package:steriymed_mobile/features/identity/data/models/open_invitation.dart';
import 'package:steriymed_mobile/features/identity/data/models/team_member_data.dart';
import 'package:steriymed_mobile/features/identity/data/repositories/team_repository.dart';
import 'package:steriymed_mobile/features/identity/presentation/bloc/team_list_bloc.dart';

class _MockRepo extends Mock implements TeamRepository {}

const _member = TeamMemberData(
  id: 'm1',
  userId: 'u1',
  name: 'Dr Martin',
  email: 'martin@example.com',
  role: 'owner',
  status: 'active',
);

const _pending = OpenInvitation(
  id: 'i1',
  email: 'new@example.com',
  role: 'practitioner',
  expired: false,
);

const _expired = OpenInvitation(
  id: 'i2',
  email: 'late@example.com',
  role: 'viewer',
  expired: true,
);

void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
    when(
      () => repo.list(forceRefresh: any(named: 'forceRefresh')),
    ).thenAnswer((_) async => [_member]);
    when(
      () => repo.invitations(),
    ).thenAnswer((_) async => [_pending, _expired]);
  });

  group('loading', () {
    blocTest<TeamListBloc, TeamListState>(
      'loads members and open invitations for someone who can invite',
      build: () => TeamListBloc(repo, loadInvitations: true),
      act: (b) => b.add(const LoadTeam()),
      verify: (b) {
        expect(b.state.members, [_member]);
        expect(b.state.invitations.map((i) => i.id), ['i1', 'i2']);
        expect(b.state.invitations.last.expired, isTrue);
      },
    );

    blocTest<TeamListBloc, TeamListState>(
      'never asks for invitations when the user may not manage them',
      build: () => TeamListBloc(repo),
      act: (b) => b.add(const LoadTeam()),
      verify: (b) {
        expect(b.state.members, [_member]);
        verifyNever(() => repo.invitations());
      },
    );

    blocTest<TeamListBloc, TeamListState>(
      'a failure to load invitations keeps the members and says so',
      build: () {
        when(() => repo.invitations()).thenThrow(
          const ApiException(
            code: 'SERVER_ERROR',
            message: 'panne',
            statusCode: 500,
          ),
        );
        return TeamListBloc(repo, loadInvitations: true);
      },
      act: (b) => b.add(const LoadTeam()),
      verify: (b) {
        expect(b.state.status, TeamStatus.success);
        expect(b.state.members, [_member]);
        expect(b.state.invitationsError, 'panne');
      },
    );

    blocTest<TeamListBloc, TeamListState>(
      'a failure to load members shows the error page',
      build: () {
        when(
          () => repo.list(forceRefresh: any(named: 'forceRefresh')),
        ).thenThrow(
          const ApiException(
            code: 'SERVER_ERROR',
            message: 'panne',
            statusCode: 500,
          ),
        );
        return TeamListBloc(repo, loadInvitations: true);
      },
      act: (b) => b.add(const LoadTeam()),
      verify: (b) {
        expect(b.state.status, TeamStatus.failure);
        verifyNever(() => repo.invitations());
      },
    );
  });

  group('invitation actions', () {
    blocTest<TeamListBloc, TeamListState>(
      'resend calls the server, reports success and reloads the list',
      build: () {
        when(() => repo.resendInvitation('i2')).thenAnswer((_) async {});
        return TeamListBloc(repo, loadInvitations: true);
      },
      act: (b) => b.add(const ResendInvitation('i2')),
      verify: (b) {
        verify(() => repo.resendInvitation('i2')).called(1);
        verify(() => repo.invitations()).called(1);
        expect(b.state.actionMessage, 'Invitation renvoyée.');
        expect(b.state.actionError, isNull);
      },
    );

    blocTest<TeamListBloc, TeamListState>(
      'revoke calls the server and reports success',
      build: () {
        when(() => repo.revokeInvitation('i1')).thenAnswer((_) async {});
        return TeamListBloc(repo, loadInvitations: true);
      },
      act: (b) => b.add(const RevokeInvitation('i1')),
      verify: (b) {
        verify(() => repo.revokeInvitation('i1')).called(1);
        expect(b.state.actionMessage, 'Invitation annulée.');
      },
    );

    blocTest<TeamListBloc, TeamListState>(
      'a refused action is reported in French by its code, with no success text',
      build: () {
        when(() => repo.resendInvitation('i1')).thenThrow(
          const ApiException(
            code: 'INVITATION_ALREADY_ACCEPTED',
            message: 'This invitation has already been accepted.',
            statusCode: 409,
          ),
        );
        return TeamListBloc(repo, loadInvitations: true);
      },
      act: (b) => b.add(const ResendInvitation('i1')),
      verify: (b) {
        expect(
          b.state.actionError,
          'Cette personne a déjà rejoint le cabinet.',
        );
        expect(b.state.actionMessage, isNull);
      },
    );

    blocTest<TeamListBloc, TeamListState>(
      'the notice is cleared once shown',
      build: () => TeamListBloc(repo),
      seed: () => const TeamListState(actionMessage: 'x', actionError: 'y'),
      act: (b) => b.add(const ClearTeamNotice()),
      verify: (b) {
        expect(b.state.actionMessage, isNull);
        expect(b.state.actionError, isNull);
      },
    );
  });
}
