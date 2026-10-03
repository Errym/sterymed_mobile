// Team screen (Phase 3, R02/R05): who can see open invitations, resend or
// cancel them, and who may disable whom. The server enforces every rule; the
// screen must not offer what the server will refuse.

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/storage/session_store.dart';
import 'package:steriymed_mobile/features/identity/data/models/open_invitation.dart';
import 'package:steriymed_mobile/features/identity/data/models/team_member_data.dart';
import 'package:steriymed_mobile/features/identity/data/repositories/team_repository.dart';
import 'package:steriymed_mobile/features/identity/presentation/screens/team_list_screen.dart';

import '../helpers/pump_app.dart';

class _MockRepo extends Mock implements TeamRepository {}

class _MockSession extends Mock implements SessionStore {}

const _owner = TeamMemberData(
  id: 'tu-owner',
  userId: 'u-owner',
  name: 'Dr Direction',
  email: 'owner@example.com',
  role: 'owner',
  status: 'active',
);
const _nurse = TeamMemberData(
  id: 'tu-nurse',
  userId: 'u-nurse',
  name: 'Awa Praticienne',
  email: 'nurse@example.com',
  role: 'practitioner',
  status: 'active',
);
const _pending = OpenInvitation(
  id: 'inv-1',
  email: 'new@example.com',
  role: 'viewer',
  expired: false,
);
const _expired = OpenInvitation(
  id: 'inv-2',
  email: 'late@example.com',
  role: 'practitioner',
  expired: true,
);

void main() {
  late _MockRepo repo;
  late _MockSession session;

  void signInAs(String role, {Set<String>? permissions}) {
    when(() => session.role).thenReturn(role);
    when(() => session.userId).thenReturn('u-me');
    when(() => session.hasPermission(any())).thenAnswer(
      (i) => (permissions ?? {'invitations.create', 'memberships.disable'})
          .contains(i.positionalArguments.first),
    );
  }

  setUp(() {
    repo = _MockRepo();
    session = _MockSession();
    when(
      () => repo.list(forceRefresh: any(named: 'forceRefresh')),
    ).thenAnswer((_) async => [_owner, _nurse]);
    when(
      () => repo.invitations(),
    ).thenAnswer((_) async => [_pending, _expired]);
    final di = GetIt.instance;
    if (di.isRegistered<TeamRepository>()) di.unregister<TeamRepository>();
    if (di.isRegistered<SessionStore>()) di.unregister<SessionStore>();
    GetIt.instance.registerSingleton<TeamRepository>(repo);
    GetIt.instance.registerSingleton<SessionStore>(session);
  });

  tearDown(() {
    GetIt.instance.unregister<TeamRepository>();
    GetIt.instance.unregister<SessionStore>();
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(tester, const TeamListScreen());
    await tester.pumpAndSettle();
  }

  testWidgets('an owner sees open invitations with their state', (
    tester,
  ) async {
    signInAs('owner');
    await open(tester);

    expect(find.text('Invitations en attente (2)'), findsOneWidget);
    expect(find.text('new@example.com'), findsOneWidget);
    expect(find.text('late@example.com'), findsOneWidget);
    expect(find.text('EXPIRÉE'), findsOneWidget);
    expect(find.text('Renvoyer (nouveau lien)'), findsOneWidget);
  });

  testWidgets('someone who cannot invite never asks for invitations', (
    tester,
  ) async {
    signInAs('viewer', permissions: {});
    await open(tester);

    verifyNever(() => repo.invitations());
    expect(find.textContaining('Invitations en attente'), findsNothing);
    expect(find.byTooltip('Inviter un membre'), findsNothing);
    expect(find.byTooltip('Désactiver'), findsNothing);
  });

  testWidgets('resending calls the server and confirms', (tester) async {
    signInAs('owner');
    when(() => repo.resendInvitation('inv-1')).thenAnswer((_) async {});
    await open(tester);

    await tester.tap(find.text('Renvoyer').first);
    await tester.pumpAndSettle();

    verify(() => repo.resendInvitation('inv-1')).called(1);
    expect(find.text('Invitation renvoyée.'), findsOneWidget);
  });

  testWidgets('cancelling asks first, then revokes', (tester) async {
    signInAs('owner');
    when(() => repo.revokeInvitation('inv-1')).thenAnswer((_) async {});
    await open(tester);

    await tester.tap(find.text('Annuler').first);
    await tester.pumpAndSettle();
    verifyNever(() => repo.revokeInvitation(any()));

    await tester.tap(find.text('Annuler l\'invitation'));
    await tester.pumpAndSettle();
    verify(() => repo.revokeInvitation('inv-1')).called(1);
  });

  testWidgets('an admin cannot disable an owner, but can disable others', (
    tester,
  ) async {
    signInAs('admin');
    await open(tester);

    // Two members, only the practitioner is disableable.
    expect(find.byTooltip('Désactiver'), findsOneWidget);
  });

  testWidgets('an owner can disable the other members', (tester) async {
    signInAs('owner');
    await open(tester);

    expect(find.byTooltip('Désactiver'), findsNWidgets(2));
  });
}
