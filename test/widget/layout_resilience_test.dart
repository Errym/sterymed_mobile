// Phase 7 / T7.7: nothing overflows or hides its actions on a small phone, with
// the user's text enlarged to 130%, or on a tablet. A RenderFlex overflow is a
// test failure, so a clipped button cannot ship unnoticed.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/network/cursor_page.dart';
import 'package:steriymed_mobile/core/security/app_guard.dart';
import 'package:steriymed_mobile/core/storage/session_store.dart';
import 'package:steriymed_mobile/features/alerts/data/repositories/alert_repository.dart';
import 'package:steriymed_mobile/features/alerts/presentation/screens/alert_list_screen.dart';
import 'package:steriymed_mobile/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:steriymed_mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:steriymed_mobile/features/dashboard/data/models/dashboard_data.dart';
import 'package:steriymed_mobile/features/dashboard/data/repositories/dashboard_repository.dart';
import 'package:steriymed_mobile/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:steriymed_mobile/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:steriymed_mobile/features/history/data/repositories/audit_repository.dart';
import 'package:steriymed_mobile/features/history/presentation/screens/audit_list_screen.dart';
import 'package:steriymed_mobile/features/prosthetic/data/models/prosthetic_case_data.dart';
import 'package:steriymed_mobile/features/prosthetic/data/models/prosthetic_dashboard_data.dart';
import 'package:steriymed_mobile/features/prosthetic/data/repositories/prosthetic_repository.dart';
import 'package:steriymed_mobile/features/prosthetic/presentation/screens/prosthetic_case_detail_screen.dart';
import 'package:steriymed_mobile/features/prosthetic/presentation/screens/prosthetic_home_screen.dart';
import 'package:steriymed_mobile/features/reporting/data/models/export_request_data.dart';
import 'package:steriymed_mobile/features/reporting/data/repositories/evidence_search_repository.dart';
import 'package:steriymed_mobile/features/reporting/data/repositories/export_repository.dart';
import 'package:steriymed_mobile/features/reporting/presentation/screens/data_export_request_screen.dart';
import 'package:steriymed_mobile/features/reporting/presentation/screens/evidence_search_screen.dart';

import '../fixtures/alert_fixture.dart';
import '../fixtures/audit_event_fixture.dart';
import '../fixtures/prosthetic_case_fixture.dart';
import '../helpers/pump_app.dart';
import '../mocks/mock_repositories.dart';

class _MockSession extends Mock implements SessionStore {}

class _MockProsthetic extends Mock implements ProstheticRepository {}

class _MockAudit extends Mock implements AuditRepository {}

class _MockExports extends Mock implements ExportRepository {}

class _MockEvidence extends Mock implements EvidenceSearchRepository {}

class _MockDashboard extends Mock implements DashboardRepository {}

void _register<T extends Object>(T v) {
  if (GetIt.instance.isRegistered<T>()) GetIt.instance.unregister<T>();
  GetIt.instance.registerSingleton<T>(v);
}

/// 320x568 is a small, old phone; 1.3 is the user's "large text" setting;
/// 1024x768 is a tablet.
const _viewports = <String, (Size, double)>{
  'small phone, text 130%': (Size(320, 568), 1.3),
  'phone, text 100%': (Size(390, 844), 1.0),
  'tablet': (Size(1024, 768), 1.0),
};

/// flutter_test renders every glyph as a full-width Ahem square unless the
/// real font is loaded, which would report overflows that no phone has.
Future<void> _loadInter() async {
  final loader = FontLoader('Inter');
  for (final f in const ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    loader.addFont(rootBundle.load('assets/fonts/Inter-$f.ttf'));
  }
  await loader.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _MockSession session;
  late _MockProsthetic prosthetic;

  setUpAll(_loadInter);

  setUp(() {
    session = _MockSession();
    when(() => session.hasPermission(any())).thenReturn(true);
    when(() => session.userName).thenReturn('Dr Test');
    when(() => session.userEmail).thenReturn('dr.test@example.com');
    when(() => session.role).thenReturn('owner');
    when(() => session.isOwner).thenReturn(true);
    _register<SessionStore>(session);

    prosthetic = _MockProsthetic();
    when(() => prosthetic.dashboard(forceRefresh: any(named: 'forceRefresh')))
        .thenAnswer((_) async => const ProstheticDashboardData(
              activeCases: 12,
              atLaboratory: 3,
              returnedToPractice: 2,
              waitingForPlacement: 5,
              placementsToday: 1,
              placementsThisWeek: 4,
              depositsOrBalancesDue: 6,
            ));
    when(() => prosthetic.show(any())).thenAnswer((_) async => buildProstheticCase(
          status: ProstheticCaseStatus.placementScheduled,
          laboratoryName: 'Laboratoire Dentaire du Centre',
          practitionerName: 'Docteur Prénom-Composé Nom-Très-Long',
          depositRequested: true,
          remainingBalance: 120.5,
          totalAmount: 800,
          notes: 'Une remarque assez longue pour vérifier le retour à la '
              'ligne sur un petit écran avec un texte agrandi.',
        ));
    when(() => prosthetic.statusHistory(any())).thenAnswer((_) async => []);
    when(() => prosthetic.listAttachments(any())).thenAnswer((_) async => []);
    _register<ProstheticRepository>(prosthetic);
  });

  tearDown(() => GetIt.instance.reset());

  Future<void> check(
    WidgetTester tester,
    (Size, double) vp,
    Widget screen,
  ) async {
    tester.view.physicalSize = vp.$1 * 2;
    tester.view.devicePixelRatio = 2;
    tester.platformDispatcher.textScaleFactorTestValue = vp.$2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearAllTestValues();
    });
    await pumpApp(tester, screen);
    await tester.pumpAndSettle();
    // Any RenderFlex overflow or build error is reported as an exception.
    final problem = tester.takeException();
    expect(
      problem,
      isNull,
      reason: problem is FlutterError ? problem.toStringDeep() : '$problem',
    );
  }

  for (final vp in _viewports.entries) {
    group('on ${vp.key}', () {
      testWidgets('prosthetic dashboard', (tester) async {
        await check(tester, vp.value, const ProstheticHomeScreen());
        expect(find.text('Travaux actifs'), findsOneWidget);
      });

      testWidgets('prosthetic case with the payment block', (tester) async {
        await check(
          tester,
          vp.value,
          const ProstheticCaseDetailScreen(caseId: 'case-1'),
        );
      });

      testWidgets('alerts', (tester) async {
        final repo = MockAlertRepository();
        when(() => repo.getActiveAlerts(
              forceRefresh: any(named: 'forceRefresh'),
              type: any(named: 'type'),
              state: any(named: 'state'),
            )).thenAnswer((_) async => CursorPage(items: [
              buildAlert(id: 'a1'),
              buildAlert(id: 'a2', type: 'near_expiry'),
            ]));
        await check(
          tester,
          vp.value,
          RepositoryProvider<AlertRepository>.value(
            value: repo,
            child: const AlertListScreen(),
          ),
        );
      });

      testWidgets('audit journal', (tester) async {
        final repo = _MockAudit();
        when(() => repo.list(
              cursor: any(named: 'cursor'),
              action: any(named: 'action'),
              actorId: any(named: 'actorId'),
              subjectType: any(named: 'subjectType'),
              from: any(named: 'from'),
              to: any(named: 'to'),
              forceRefresh: any(named: 'forceRefresh'),
            )).thenAnswer((_) async => CursorPage(items: [buildAuditEvent()]));
        _register<AuditRepository>(repo);
        await check(tester, vp.value, const AuditListScreen());
      });

      testWidgets('evidence search with its form', (tester) async {
        _register<EvidenceSearchRepository>(_MockEvidence());
        await check(tester, vp.value, const EvidenceSearchScreen());
        // The search button is always reachable, however small the screen.
        expect(find.text('Rechercher'), findsOneWidget);
      });

      testWidgets('exports', (tester) async {
        final repo = _MockExports();
        when(() => repo.list(forceRefresh: any(named: 'forceRefresh')))
            .thenAnswer((_) async => [
                  ExportRequestData(
                    id: 'abcdef12-3456-7890-aaaa-bbbbbbbbbbbb',
                    status: 'completed',
                    requestedByName: 'Docteur Nom-Très-Long',
                    requestedAt: DateTime(2026, 9, 20, 14, 30),
                    sizeBytes: 5 * 1024 * 1024,
                    recordCount: 1234,
                    fileCount: 56,
                  ),
                ]);
        _register<ExportRepository>(repo);
        await check(tester, vp.value, const DataExportRequestScreen());
      });

      testWidgets('main dashboard', (tester) async {
        final repo = _MockDashboard();
        when(() => repo.fetch(forceRefresh: any(named: 'forceRefresh')))
            .thenAnswer((_) async => const DashboardData(
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
                      value: 12,
                      approximate: true,
                      route: '/app/alerts',
                    ),
                    DashboardKpi(
                      id: 'today_cycles',
                      label: 'Cycles du jour',
                      value: null,
                      route: '/app/cycles',
                    ),
                  ],
                  unavailable: {'cycles'},
                  attention: [],
                  todayCycles: [],
                  recentProcedures: [],
                ));
        await check(
          tester,
          vp.value,
          BlocProvider(
            create: (_) => DashboardCubit(repo, session)..load(),
            child: const DashboardScreen(),
          ),
        );
      });

      testWidgets('login', (tester) async {
        await check(
          tester,
          vp.value,
          BlocProvider(
            create: (_) => AuthBloc(MockAuthRepository()),
            child: const LoginScreen(),
          ),
        );
      });

      testWidgets('lock and update-required screens', (tester) async {
        await check(
          tester,
          vp.value,
          Column(
            children: [
              Expanded(
                child: LockScreen(onUnlock: () async => false, onSignOut: () {}),
              ),
              const Expanded(
                child: UpdateRequiredScreen(current: '0.2.0', required: '1.0.0'),
              ),
            ],
          ),
        );
      });
    });
  }
}
