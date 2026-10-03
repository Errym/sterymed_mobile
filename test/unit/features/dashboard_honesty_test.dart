// Phase 7 / T7.1: a failed call is "indisponible", never a zero.

import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/storage/session_store.dart';
import 'package:steriymed_mobile/features/dashboard/data/datasources/dashboard_remote_datasource.dart';
import 'package:steriymed_mobile/features/dashboard/data/models/dashboard_data.dart';
import 'package:steriymed_mobile/features/dashboard/data/repositories/dashboard_repository.dart';
import 'package:steriymed_mobile/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:steriymed_mobile/features/dashboard/presentation/cubit/dashboard_state.dart';
import 'package:steriymed_mobile/features/dashboard/presentation/screens/dashboard_screen.dart';

import '../../helpers/pump_app.dart';

class _MockDio extends Mock implements Dio {}

class _MockRepo extends Mock implements DashboardRepository {}

class _MockSession extends Mock implements SessionStore {}

Response<dynamic> _ok(String path, Object body) => Response(
      requestOptions: RequestOptions(path: path),
      data: body,
      statusCode: 200,
    );

DioException _fail(String path) => DioException(
      requestOptions: RequestOptions(path: path),
      type: DioExceptionType.connectionError,
    );

void main() {
  group('DashboardRemoteDatasource', () {
    late _MockDio dio;

    setUp(() {
      dio = _MockDio();
    });

    void stub(String fragment, {Object? body, bool fail = false}) {
      when(() => dio.get(
            any(that: contains(fragment)),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((inv) async {
        final path = inv.positionalArguments.first as String;
        if (fail) throw _fail(path);
        return _ok(path, body ?? {'data': []});
      });
    }

    test('a failed alerts call is unavailable, not "0 alerts"', () async {
      stub('cycles', body: {'data': []});
      stub('alerts', fail: true);
      stub('audit', body: {'data': []});
      stub('devices', body: {'data': []});

      final data = await DashboardRemoteDatasource(dio).fetch();
      final alerts = data.kpis.firstWhere((k) => k.id == 'pending_alerts');
      expect(alerts.value, isNull);
      expect(alerts.isUnavailable, isTrue);
      expect(data.unavailable, {'alerts'});
      // The healthy sections still show a real zero.
      expect(data.kpis.firstWhere((k) => k.id == 'active_cycles').value, 0);
    });

    test('an alert in the attention list is read in French, like in Alertes',
        () async {
      stub('cycles', body: {'data': []});
      stub('alerts', body: {
        'data': [
          {
            'id': 'a1',
            'type': 'low_stock',
            'message': 'Stock for "Gants nitrile" is below threshold (20/500).',
          },
          {'id': 'a2', 'type': 'unknown_kind', 'message': 'Texte inconnu'},
        ]
      });
      stub('audit', body: {'data': []});
      stub('devices', body: {'data': []});

      final data = await DashboardRemoteDatasource(dio).fetch();
      final labels = data.attention.map((a) => a.label).toList();
      expect(labels, contains('Stock de « Gants nitrile » sous le seuil (20 sur 500).'));
      // A text the app does not know is shown exactly as received.
      expect(labels, contains('Texte inconnu'));
    });

    test('every call failing is an error, not a screen of zeros', () async {
      stub('cycles', fail: true);
      stub('alerts', fail: true);
      stub('audit', fail: true);
      stub('devices', fail: true);
      expect(
        DashboardRemoteDatasource(dio).fetch(),
        throwsA(isA<DashboardUnavailableException>()),
      );
    });

    test('a full first page is shown as "at least", not as the exact figure',
        () async {
      stub('cycles', body: {'data': []});
      stub('alerts', body: {
        'data': [
          {'id': 'a1', 'message': 'Stock bas', 'severity': 'warning'},
        ],
        'meta': {'next_cursor': 'abc'},
      });
      stub('audit', body: {'data': []});
      stub('devices', body: {'data': []});
      final data = await DashboardRemoteDatasource(dio).fetch();
      final alerts = data.kpis.firstWhere((k) => k.id == 'pending_alerts');
      expect(alerts.value, 1);
      expect(alerts.approximate, isTrue);
    });
  });

  group('DashboardCubit', () {
    late _MockRepo repo;
    late _MockSession session;

    setUp(() {
      repo = _MockRepo();
      session = _MockSession();
      when(() => session.userName).thenReturn('Dr Test');
    });

    const good = DashboardData(
      greeting: 'Bonjour',
      userName: '',
      kpis: [],
      attention: [],
      todayCycles: [],
      recentProcedures: [],
    );

    blocTest<DashboardCubit, DashboardState>(
      'a failed refresh keeps the earlier figures and marks them stale',
      build: () => DashboardCubit(repo, session),
      act: (c) async {
        when(() => repo.fetch(forceRefresh: any(named: 'forceRefresh')))
            .thenAnswer((_) async => good);
        await c.load();
        when(() => repo.fetch(forceRefresh: any(named: 'forceRefresh')))
            .thenAnswer((_) async => throw Exception('offline'));
        await c.load();
      },
      expect: () => [
        isA<DashboardLoading>(),
        isA<DashboardLoaded>().having((s) => s.data.stale, 'stale', false),
        isA<DashboardLoaded>().having((s) => s.data.stale, 'stale', true),
      ],
    );

    blocTest<DashboardCubit, DashboardState>(
      'every load asks the server again (never a cached all-clear)',
      build: () => DashboardCubit(repo, session),
      setUp: () => when(
              () => repo.fetch(forceRefresh: any(named: 'forceRefresh')))
          .thenAnswer((_) async => good),
      act: (c) => c.load(),
      verify: (_) =>
          verify(() => repo.fetch(forceRefresh: true)).called(1),
    );
  });

  group('DashboardScreen', () {
    late _MockRepo repo;
    late _MockSession session;

    setUp(() {
      repo = _MockRepo();
      session = _MockSession();
      when(() => session.userName).thenReturn('Dr Test');
      when(() => session.userEmail).thenReturn('t@t.fr');
      when(() => session.role).thenReturn('owner');
      when(() => session.isOwner).thenReturn(true);
      when(() => session.hasPermission(any())).thenReturn(false);
      if (GetIt.instance.isRegistered<SessionStore>()) {
        GetIt.instance.unregister<SessionStore>();
      }
      GetIt.instance.registerSingleton<SessionStore>(session);
    });

    tearDown(() => GetIt.instance.reset());

    testWidgets('an unavailable figure is a dash plus a banner, never "0"',
        (tester) async {
      when(() => repo.fetch(forceRefresh: any(named: 'forceRefresh')))
          .thenAnswer((_) async => const DashboardData(
                greeting: 'Bonjour',
                userName: '',
                unavailable: {'alerts'},
                kpis: [
                  DashboardKpi(
                    id: 'pending_alerts',
                    label: 'Alertes actives',
                    value: null,
                    route: '/app/alerts',
                  ),
                  DashboardKpi(
                    id: 'active_cycles',
                    label: 'Cycles en cours',
                    value: 0,
                    route: '/app/cycles',
                  ),
                ],
                attention: [],
                todayCycles: [],
                recentProcedures: [],
              ));
      await pumpApp(
        tester,
        BlocProvider(
          create: (_) => DashboardCubit(repo, session)..load(),
          child: const DashboardScreen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dashboard-status-banner')), findsOneWidget);
      expect(find.byKey(const Key('dashboard-alerts-unavailable')),
          findsOneWidget);
      expect(find.text('—'), findsOneWidget);
      // The one real zero (cycles) is still a zero.
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('a total failure shows the error with a retry',
        (tester) async {
      when(() => repo.fetch(forceRefresh: any(named: 'forceRefresh')))
          .thenAnswer((_) async => throw const DashboardUnavailableException());
      await pumpApp(
        tester,
        BlocProvider(
          create: (_) => DashboardCubit(repo, session)..load(),
          child: const DashboardScreen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });
  });
}
