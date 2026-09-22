import 'package:flutter/material.dart';
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

  testWidgets('renders KPIs once loaded', (tester) async {
    when(() => repo.fetch(forceRefresh: any(named: 'forceRefresh')))
        .thenAnswer((_) async => _dashboard);

    await pumpApp(
      tester,
      BlocProvider(
        create: (_) => DashboardCubit(repo, session)..load(),
        child: const DashboardScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cycles en cours'), findsOneWidget);
    expect(find.text('Alertes actives'), findsOneWidget);
  });

  testWidgets('shows error view with retry on failure', (tester) async {
    when(() => repo.fetch(forceRefresh: any(named: 'forceRefresh')))
        .thenThrow(Exception('boom'));

    await pumpApp(
      tester,
      BlocProvider(
        create: (_) => DashboardCubit(repo, session)..load(),
        child: const DashboardScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });
}
