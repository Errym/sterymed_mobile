import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/errors/api_exception.dart';
import 'package:steriymed_mobile/core/network/cursor_page.dart';
import 'package:steriymed_mobile/core/storage/session_store.dart';
import 'package:steriymed_mobile/core/theme/typography.dart';
import 'package:steriymed_mobile/features/alerts/data/models/alert_data.dart';
import 'package:steriymed_mobile/features/alerts/data/repositories/alert_repository.dart';
import 'package:steriymed_mobile/features/alerts/presentation/bloc/alert_list_bloc.dart';
import 'package:steriymed_mobile/features/alerts/presentation/screens/alert_list_screen.dart';
import '../fixtures/alert_fixture.dart';
import '../helpers/pump_app.dart';
import '../mocks/mock_repositories.dart';

class MockSessionStore extends Mock implements SessionStore {}

/// Matches the group header specifically, not the per-alert severity
/// badge -- both render the same French label as literal text.
Finder findGroupHeader(String label) => find.byWidgetPredicate(
      (w) =>
          w is Text &&
          w.data == label &&
          w.style?.fontSize == AppTypography.sectionTitle.fontSize,
    );

void main() {
  late MockAlertRepository repo;
  late MockSessionStore session;

  setUp(() {
    repo = MockAlertRepository();
    session = MockSessionStore();
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

  testWidgets('renders severity groups', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    when(() => repo.getActiveAlerts(
            forceRefresh: any(named: 'forceRefresh'),
            type: any(named: 'type'),
            state: any(named: 'state'),
          ))
        .thenAnswer((_) async => CursorPage(items: [
              buildAlert(id: 'a1', severity: AlertSeverity.critical),
              buildAlert(id: 'a2', severity: AlertSeverity.warning),
              buildAlert(id: 'a3', severity: AlertSeverity.info),
            ]));

    await pumpApp(
      tester,
      RepositoryProvider<AlertRepository>.value(
        value: repo,
        child: Builder(
          builder: (ctx) => BlocProvider(
            create: (_) => AlertListBloc(repo)..add(const LoadAlerts()),
            child: const AlertListScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(findGroupHeader('Critique'), findsOneWidget);
    expect(findGroupHeader('Avertissement'), findsOneWidget);
    expect(findGroupHeader('Information'), findsOneWidget);
    // The header says what needs action before the list does.
    expect(find.byKey(const Key('alerts-summary')), findsOneWidget);
    expect(find.text('1 alerte critique requiert une action'), findsOneWidget);
  });

  test('alert age reads naturally', () {
    final now = DateTime(2026, 10, 3, 12);
    expect(alertAge(now.subtract(const Duration(seconds: 20)), now: now),
        "à l'instant");
    expect(alertAge(now.subtract(const Duration(minutes: 25)), now: now),
        'il y a 25 min');
    expect(alertAge(now.subtract(const Duration(hours: 5)), now: now),
        'il y a 5 h');
    expect(alertAge(now.subtract(const Duration(hours: 30)), now: now),
        'hier');
    expect(alertAge(now.subtract(const Duration(days: 4)), now: now),
        'il y a 4 j');
  });

  test('each alert type points at the screen that lets you act on it', () {
    AlertData a(String type, String subject, {String? id}) => AlertData(
          id: 'x',
          type: type,
          severity: AlertSeverity.warning,
          state: 'open',
          subjectType: subject,
          subjectId: id,
          message: 'm',
          createdAt: DateTime(2026),
        );
    expect(alertTarget(a('failed_cycle', r'App\Cycle', id: 'c1'))!.route,
        '/app/cycles/c1');
    expect(alertTarget(a('low_stock', 'Product', id: 'p'))!.route,
        '/app/stock');
    expect(alertTarget(a('expired', 'Batch', id: 'b'))!.route, '/app/batches');
    expect(alertTarget(a('near_expiry', 'Batch'))!.route, '/app/batches');
    expect(alertTarget(a('mystery', 'Thing')), isNull);
  });

  testWidgets('shows empty view when no alerts', (tester) async {
    when(() => repo.getActiveAlerts(
            forceRefresh: any(named: 'forceRefresh'),
            type: any(named: 'type'),
            state: any(named: 'state'),
          ))
        .thenAnswer((_) async => const CursorPage(items: []));

    await pumpApp(
      tester,
      RepositoryProvider<AlertRepository>.value(
        value: repo,
        child: BlocProvider(
          create: (_) => AlertListBloc(repo)..add(const LoadAlerts()),
          child: const AlertListScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Aucune alerte active'), findsOneWidget);
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await pumpApp(
      tester,
      RepositoryProvider<AlertRepository>.value(
        value: repo,
        child: const AlertListScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  void stubList(List<AlertData> items, {String? type, String? state = 'open'}) {
    when(() => repo.getActiveAlerts(
          forceRefresh: any(named: 'forceRefresh'),
          type: type,
          state: state,
        )).thenAnswer((_) async => CursorPage(items: items));
  }

  testWidgets('tapping a type chip asks the server for that type',
      (tester) async {
    stubList([buildAlert(id: 'a1')]);
    stubList([buildAlert(id: 'n1', type: 'near_expiry')], type: 'near_expiry');
    await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('alert-type-near_expiry')));
    await tester.pumpAndSettle();
    verify(() => repo.getActiveAlerts(
          forceRefresh: any(named: 'forceRefresh'),
          type: 'near_expiry',
          state: 'open',
        )).called(1);
  });

  testWidgets('the Résolues view shows who resolved and when, with no button',
      (tester) async {
    stubList([buildAlert(id: 'a1')]);
    stubList(
      [
        buildAlert(
          id: 'r1',
          state: 'resolved',
          resolvedAt: DateTime(2026, 9, 19, 8, 30),
          resolvedByName: 'Dr Test',
        ),
      ],
      state: 'resolved',
    );
    await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('alert-state-resolved')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('alert-resolved-r1')), findsOneWidget);
    expect(find.textContaining('Dr Test'), findsOneWidget);
    expect(find.text('Marquer comme résolu'), findsNothing);
  });

  testWidgets('a failed resolve tells the user why and keeps the alert',
      (tester) async {
    stubList([buildAlert(id: 'a1')]);
    when(() => repo.resolveAlert('a1')).thenThrow(const ApiException(
      code: 'server_error',
      message: 'Le serveur est indisponible.',
    ));
    await pumpScreen(tester);
    await tester.tap(find.text('Marquer comme résolu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Résoudre'));
    await tester.pumpAndSettle();
    expect(find.text('Le serveur est indisponible.'), findsOneWidget);
    expect(find.text('Stock faible pour Gants nitrile'), findsOneWidget);
  });

  testWidgets('a successful resolve says so and removes the alert',
      (tester) async {
    stubList([buildAlert(id: 'a1')]);
    when(() => repo.resolveAlert('a1')).thenAnswer((_) async {});
    await pumpScreen(tester);
    await tester.tap(find.text('Marquer comme résolu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Résoudre'));
    await tester.pumpAndSettle();
    expect(find.text('Alerte résolue.'), findsOneWidget);
    expect(find.text('Stock faible pour Gants nitrile'), findsNothing);
  });

  testWidgets('without alerts.manage there is no resolve button at all',
      (tester) async {
    when(() => session.hasPermission(any())).thenReturn(false);
    stubList([buildAlert(id: 'a1')]);
    await pumpScreen(tester);
    expect(find.text('Stock faible pour Gants nitrile'), findsOneWidget);
    expect(find.text('Marquer comme résolu'), findsNothing);
  });

  testWidgets('a failed refresh keeps the list but says it may be stale',
      (tester) async {
    stubList([buildAlert(id: 'a1')]);
    await pumpScreen(tester);
    when(() => repo.getActiveAlerts(
          forceRefresh: true,
          type: any(named: 'type'),
          state: any(named: 'state'),
        )).thenThrow(
        const ApiException(code: 'network', message: 'Hors ligne.'));
    BlocProvider.of<AlertListBloc>(
      tester.element(find.text('Stock faible pour Gants nitrile')),
    ).add(const RefreshAlerts());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('alerts-stale-banner')), findsOneWidget);
    expect(find.text('Stock faible pour Gants nitrile'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });
}
