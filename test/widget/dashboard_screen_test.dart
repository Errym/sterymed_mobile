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
    when(() => session.hasPermission(any())).thenReturn(false);
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
    expect(find.text('Cycles de stérilisation'), findsNothing);
    expect(find.text('Aucun module accessible'), findsOneWidget);
  });

  testWidgets('shows only cycles menu item when cycles.view is granted',
      (tester) async {
    when(() => session.hasPermission(any())).thenAnswer((invocation) {
      final permission = invocation.positionalArguments.first as String;
      return permission == 'cycles.view';
    });
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

    expect(find.text('Cycles de stérilisation'), findsOneWidget);
    expect(find.text('Stock & Catalogue'), findsNothing);
    expect(find.text('Lots'), findsNothing);
    expect(find.text('Travaux prothétiques'), findsNothing);
    expect(find.text('Catalogue produits'), findsNothing);
    expect(find.text('Fournisseurs'), findsNothing);
    expect(find.text('Commandes & Réceptions'), findsNothing);
    expect(find.text('Gestion des patients'), findsNothing);
    expect(find.text('Non-Conformités & Rappels'), findsNothing);
    expect(find.text('Journal d\'Audit'), findsNothing);
    expect(find.text('Recherche de preuves'), findsNothing);
    expect(find.text('Équipe & Droits'), findsNothing);
    expect(find.text('Sites & Espaces'), findsNothing);
    expect(find.text('Appareils & Programmes'), findsNothing);
    expect(find.text('Règles DLU'), findsNothing);
    expect(find.text('Export Données'), findsNothing);
    expect(find.text('Aucun module accessible'), findsNothing);
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
