// The home screen is not one screen: what it shows is decided by what the
// signed-in role may see, and every figure comes from the server.

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

class _MockRepo extends Mock implements DashboardRepository {}

class _MockSession extends Mock implements SessionStore {}

DashboardData _data({
  List<DashboardKpi> kpis = const [],
  List<DashboardAttentionItem> attention = const [],
  DashboardInsights insights = const DashboardInsights(),
  List<DashboardRecentProcedure> recent = const [],
}) =>
    DashboardData(
      greeting: 'Bonjour',
      userName: 'Test',
      kpis: kpis,
      attention: attention,
      todayCycles: const [],
      recentProcedures: recent,
      insights: insights,
    );

void main() {
  late _MockRepo repo;
  late _MockSession session;

  Future<void> show(
    WidgetTester tester, {
    required String role,
    required Set<String> permissions,
    required DashboardData data,
  }) async {
    when(() => session.role).thenReturn(role);
    when(() => session.tenantName).thenReturn('Cabinet Test');
    when(() => session.hasPermission(any())).thenAnswer(
      (i) => permissions.contains(i.positionalArguments.first as String),
    );
    when(() => repo.fetch(forceRefresh: any(named: 'forceRefresh')))
        .thenAnswer((_) async => data);
    // Tall enough that the lazy list builds every section.
    tester.view.physicalSize = const Size(1000, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      BlocProvider(
        create: (_) => DashboardCubit(repo, session)..load(),
        child: const DashboardScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    repo = _MockRepo();
    session = _MockSession();
    when(() => session.userName).thenReturn('Test');
    when(() => session.userEmail).thenReturn('t@t.fr');
    when(() => session.isOwner).thenReturn(false);
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

  testWidgets('the header names the clinic and the role in French',
      (tester) async {
    await show(tester,
        role: 'stock_manager', permissions: {}, data: _data());
    expect(find.text('CABINET TEST'), findsOneWidget);
    expect(find.text('Responsable stock'), findsOneWidget);
    expect(find.text('Stock, commandes et réceptions'), findsOneWidget);
  });

  testWidgets('a role that may not read labels gets no scan hero',
      (tester) async {
    await show(tester, role: 'viewer', permissions: {}, data: _data());
    expect(find.byKey(const Key('dashboard-scan-hero')), findsNothing);
  });

  testWidgets('a role that may read labels gets the scan hero',
      (tester) async {
    await show(tester,
        role: 'practitioner', permissions: {'labels.view'}, data: _data());
    expect(find.byKey(const Key('dashboard-scan-hero')), findsOneWidget);
    expect(find.text('Scanner une étiquette'), findsOneWidget);
  });

  testWidgets('stock manager: stock and orders, with what needs action',
      (tester) async {
    await show(
      tester,
      role: 'stock_manager',
      permissions: {'inventory.view', 'purchasing.view'},
      data: _data(
        insights: const DashboardInsights(
          stock: StockInsight(
            rows: 10,
            healthy: 7,
            low: 2,
            expired: 1,
            nearExpiry: 3,
          ),
          purchases: PurchaseInsight(toReceive: 4, late: 1),
        ),
      ),
    );
    expect(find.text('Stock'), findsOneWidget);
    expect(find.text('70 %'), findsOneWidget);
    // The headline tile and the section's own detail both carry it.
    expect(find.text('Sous le minimum'), findsNWidgets(2));
    expect(find.text('Commandes'), findsOneWidget);
    expect(find.text('Prothèses'), findsNothing);
    // The worst thing first, worded for a person.
    expect(find.text('1 lot périmé à retirer du stock'), findsOneWidget);
    expect(find.text('2 lignes de stock sous le minimum'), findsOneWidget);
    expect(find.text('1 commande en retard de livraison'), findsOneWidget);
    expect(find.text('4 commandes à réceptionner'), findsOneWidget);
  });

  testWidgets('practitioner: prosthetics, not stock', (tester) async {
    await show(
      tester,
      role: 'practitioner',
      permissions: {'prosthetic_cases.view', 'labels.view'},
      data: _data(
        insights: const DashboardInsights(
          prosthetic: ProstheticInsight(
            active: 7,
            atLaboratory: 3,
            returned: 2,
            waitingForPlacement: 2,
            placementsToday: 1,
            placementsThisWeek: 4,
            paymentsDue: 5,
          ),
        ),
      ),
    );
    expect(find.text('Prothèses'), findsOneWidget);
    expect(find.text('En attente de pose'), findsNWidgets(2));
    expect(find.text('Stock'), findsNothing);
    expect(find.text('2 prothèses en attente de pose'), findsOneWidget);
    expect(find.text('1 pose prévue aujourd\'hui'), findsOneWidget);
    expect(find.text('5 dossiers avec un solde à régler'), findsOneWidget);
  });

  testWidgets('releaser is told about cycles waiting for a decision',
      (tester) async {
    await show(
      tester,
      role: 'releaser',
      permissions: {'cycles.view', 'cycles.release'},
      data: _data(
        kpis: const [
          DashboardKpi(
            id: 'active_cycles',
            label: 'Cycles en cours',
            value: 2,
            route: '/app/cycles',
          ),
        ],
        insights: const DashboardInsights(awaitingRelease: 3),
      ),
    );
    expect(find.text('3 cycles attendent votre décision de libération'),
        findsOneWidget);
  });

  testWidgets('a stock section that could not be read says so, not "0"',
      (tester) async {
    await show(
      tester,
      role: 'stock_manager',
      permissions: {'inventory.view'},
      data: _data(
        insights: const DashboardInsights(unavailable: {'stock'}),
      ),
    );
    expect(find.text('Stock indisponible : impossible de vérifier.'),
        findsOneWidget);
    // The headline tile says "could not read" with a dash, not a zero, and
    // the section has no figures to show.
    expect(find.text('—'), findsOneWidget);
    expect(find.text('0'), findsNothing);
    expect(find.text('Sous le minimum'), findsOneWidget);
    // And it is not reported as "all clear".
    expect(find.byKey(const Key('dashboard-all-clear')), findsNothing);
  });

  testWidgets('everything in order says so', (tester) async {
    await show(
      tester,
      role: 'owner',
      permissions: {'inventory.view'},
      data: _data(
        insights: const DashboardInsights(
          stock: StockInsight(
              rows: 5, healthy: 5, low: 0, expired: 0, nearExpiry: 0),
        ),
      ),
    );
    expect(find.byKey(const Key('dashboard-all-clear')), findsOneWidget);
    expect(find.text('100 %'), findsOneWidget);
  });

  testWidgets('recent activity shows the action and who did it',
      (tester) async {
    await show(
      tester,
      role: 'owner',
      permissions: {'audit.view'},
      data: _data(
        kpis: const [
          DashboardKpi(
            id: 'audit_events',
            label: 'Événements récents',
            value: 1,
            route: '/app/audit',
          ),
        ],
        recent: const [
          DashboardRecentProcedure(
            id: 'e1',
            label: 'Cycle libéré',
            patientReference: '',
            usedAt: '2026-10-02T10:00:00Z',
            actor: 'Dr Martin',
          ),
        ],
      ),
    );
    expect(find.text('Activité récente'), findsOneWidget);
    expect(find.text('Cycle libéré'), findsOneWidget);
    expect(find.textContaining('Dr Martin'), findsOneWidget);
  });
}
