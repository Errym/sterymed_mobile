// Golden 2/4: dashboard screen. Setup mirrors
// test/widget/dashboard_screen_test.dart (same mock repository/session
// wiring and fixture data) — this file only adds a fixed surface size and
// a matchesGoldenFile assertion on top of that already-covered behavior.

@TestOn('windows')
library;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/storage/session_store.dart';
import 'package:steriymed_mobile/features/dashboard/data/models/dashboard_data.dart';
import 'package:steriymed_mobile/features/dashboard/data/repositories/dashboard_repository.dart';
import 'package:steriymed_mobile/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:steriymed_mobile/features/dashboard/presentation/screens/dashboard_screen.dart';

import '../helpers/pump_app.dart';
import 'golden_helpers.dart';

class MockDashboardRepository extends Mock implements DashboardRepository {}

class MockSessionStore extends Mock implements SessionStore {}

const _dashboard = DashboardData(
  greeting: 'Bonjour',
  userName: 'Dr Test',
  kpis: [
    DashboardKpi(
      id: 'active_cycles',
      label: 'Cycles en cours',
      value: 3,
      route: '/app/cycles',
    ),
    DashboardKpi(
      id: 'pending_alerts',
      label: 'Alertes actives',
      value: 2,
      route: '/app/alerts',
    ),
  ],
  attention: [],
  todayCycles: [],
  recentProcedures: [],
);

void main() {
  late MockDashboardRepository repo;
  late MockSessionStore session;

  setUp(() {
    repo = MockDashboardRepository();
    session = MockSessionStore();
    when(() => session.userName).thenReturn('Dr Test');
    when(() => session.userEmail).thenReturn('test@test.com');
    when(() => session.role).thenReturn('owner');
    when(() => session.isOwner).thenReturn(true);
    when(() => session.hasPermission(any())).thenReturn(true);
    if (GetIt.instance.isRegistered<SessionStore>()) {
      GetIt.instance.unregister<SessionStore>();
    }
    GetIt.instance.registerSingleton<SessionStore>(session);
  });

  tearDown(() {
    if (GetIt.instance.isRegistered<SessionStore>()) {
      GetIt.instance.unregister<SessionStore>();
    }
  });

  testWidgets('dashboard screen matches golden', (tester) async {
    when(() => repo.fetch(forceRefresh: any(named: 'forceRefresh')))
        .thenAnswer((_) async => _dashboard);
    await setGoldenSurfaceSize(tester);

    await pumpApp(
      tester,
      BlocProvider(
        create: (_) => DashboardCubit(repo, session)..load(),
        child: const DashboardScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(DashboardScreen),
      matchesGoldenFile('goldens/dashboard_screen.png'),
    );
  });
}
