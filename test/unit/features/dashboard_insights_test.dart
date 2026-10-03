// The role-dependent part of the home screen: each role only asks for what it
// may see, a section that cannot be read is "indisponible" (never a zero),
// and every figure is computed from the fields the backend really returns.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/features/dashboard/data/datasources/dashboard_remote_datasource.dart';

class _MockDio extends Mock implements Dio {}

Response<dynamic> _ok(String path, Object body) => Response(
      requestOptions: RequestOptions(path: path),
      data: body,
      statusCode: 200,
    );

DioException _fail(String path) => DioException(
      requestOptions: RequestOptions(path: path),
      type: DioExceptionType.connectionError,
    );

String _day(int offset) {
  final d = DateTime.now().add(Duration(days: offset));
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

void main() {
  late _MockDio dio;
  final asked = <String>[];

  setUp(() {
    dio = _MockDio();
    asked.clear();
  });

  /// Answers every GET whose path contains [fragment]; records what was asked.
  void stub(String fragment, {Object? body, bool fail = false}) {
    when(() => dio.get(
          any(that: contains(fragment)),
          queryParameters: any(named: 'queryParameters'),
        )).thenAnswer((inv) async {
      final path = inv.positionalArguments.first as String;
      asked.add(path);
      if (fail) throw _fail(path);
      return _ok(path, body ?? {'data': []});
    });
  }

  void stubBasics() {
    stub('cycles', body: {
      'data': [
        {'id': 'c1', 'status': 'awaiting_release', 'cycle_number': 1},
        {'id': 'c2', 'status': 'awaiting_release', 'cycle_number': 2},
        {'id': 'c3', 'status': 'released', 'cycle_number': 3},
      ],
    });
    stub('alerts');
    stub('audit-events', body: {
      'data': [
        {
          'id': 'e1',
          'action': 'cycle.released',
          'actor_label_snapshot': 'Dr Martin',
          'subject_id': 's1',
          'occurred_at': '2026-10-02T10:00:00Z',
        },
      ],
    });
    stub('devices');
  }

  group('what each role asks for', () {
    test('a role without the permission never requests that section',
        () async {
      stubBasics();
      stub('stock-levels');
      stub('purchase-orders');
      stub('prosthetic-dashboard');
      // Sees cycles and alerts only.
      final data = await DashboardRemoteDatasource(
        dio,
        (p) => p == 'cycles.view' || p == 'alerts.view',
      ).fetch();

      expect(asked.any((p) => p.contains('audit-events')), isFalse);
      expect(asked.any((p) => p.contains('stock-levels')), isFalse);
      expect(asked.any((p) => p.contains('purchase-orders')), isFalse);
      expect(asked.any((p) => p.contains('prosthetic-dashboard')), isFalse);

      // Not asked is not "unavailable": no false alarm banner for a viewer.
      expect(data.unavailable, isEmpty);
      expect(data.kpis.map((k) => k.id), isNot(contains('audit_events')));
      expect(data.insights.stock, isNull);
      expect(data.insights.unavailable, isEmpty);
    });

    test('with no permission check at all, the classic four calls are made',
        () async {
      stubBasics();
      final data = await DashboardRemoteDatasource(dio).fetch();
      expect(data.kpis.map((k) => k.id),
          containsAll(['active_cycles', 'pending_alerts', 'audit_events']));
      expect(asked.any((p) => p.contains('stock-levels')), isFalse);
    });
  });

  group('stock', () {
    test('counts low, expired and near-expiry rows with the stock rules',
        () async {
      stubBasics();
      stub('stock-levels', body: {
        'data': [
          // healthy
          {'id': 'a', 'quantity': 50, 'min_threshold': 10, 'expiry_date': _day(200)},
          // under its minimum
          {'id': 'b', 'quantity': 3, 'min_threshold': 10, 'expiry_date': _day(200)},
          // expired
          {'id': 'c', 'quantity': 20, 'min_threshold': 10, 'expiry_date': _day(-3)},
          // expires within 30 days
          {'id': 'd', 'quantity': 20, 'min_threshold': 10, 'expiry_date': _day(10)},
        ],
      });
      final data =
          await DashboardRemoteDatasource(dio, (p) => p == 'inventory.view')
              .fetch();
      final s = data.insights.stock!;
      expect(s.rows, 4);
      expect(s.low, 1);
      expect(s.expired, 1);
      expect(s.nearExpiry, 1);
      // Healthy = not low and not expired: a, d.
      expect(s.healthy, 2);
      expect(s.healthPercent, 50);
    });

    test('more rows on the server than were read marks every figure as partial',
        () async {
      stubBasics();
      stub('stock-levels', body: {
        'data': [
          {'id': 'a', 'quantity': 3, 'min_threshold': 10, 'expiry_date': _day(200)},
        ],
        'meta': {'next_cursor': 'abc'},
      });
      final s = (await DashboardRemoteDatasource(dio, (p) => p == 'inventory.view')
              .fetch())
          .insights
          .stock!;
      expect(s.partial, isTrue);
      expect(s.low, 1);
    });

    test('a complete read is not marked partial', () async {
      stubBasics();
      stub('stock-levels', body: {
        'data': [
          {'id': 'a', 'quantity': 50, 'min_threshold': 10, 'expiry_date': _day(200)},
        ],
      });
      final s = (await DashboardRemoteDatasource(dio, (p) => p == 'inventory.view')
              .fetch())
          .insights
          .stock!;
      expect(s.partial, isFalse);
    });

    test('no stock rows is "nothing to judge", not 100%', () async {
      stubBasics();
      stub('stock-levels');
      final data =
          await DashboardRemoteDatasource(dio, (p) => p == 'inventory.view')
              .fetch();
      expect(data.insights.stock!.healthPercent, isNull);
    });

    test('a stock call that fails is unavailable, never an all-clear',
        () async {
      stubBasics();
      stub('stock-levels', fail: true);
      final data =
          await DashboardRemoteDatasource(dio, (p) => p == 'inventory.view')
              .fetch();
      expect(data.insights.stock, isNull);
      expect(data.insights.unavailable, {'stock'});
      expect(data.hasUnavailable, isTrue);
    });
  });

  group('purchasing', () {
    test('counts open orders and those past their expected date', () async {
      stubBasics();
      stub('purchase-orders', body: {
        'data': [
          {'id': 'p1', 'status': 'ordered', 'expected_at': _day(-2)},
          {'id': 'p2', 'status': 'partially_received', 'expected_at': _day(5)},
          {'id': 'p3', 'status': 'received', 'expected_at': _day(-9)},
          {'id': 'p4', 'status': 'draft'},
        ],
      });
      final data =
          await DashboardRemoteDatasource(dio, (p) => p == 'purchasing.view')
              .fetch();
      expect(data.insights.purchases!.toReceive, 2);
      expect(data.insights.purchases!.late, 1);
    });
  });

  group('prosthetics', () {
    test('reads the server\'s own counters', () async {
      stubBasics();
      stub('prosthetic-dashboard', body: {
        'active_cases': 7,
        'at_laboratory': 3,
        'returned_to_practice': 2,
        'waiting_for_placement': 2,
        'placements_today': 1,
        'placements_this_week': 4,
        'deposits_or_balances_due': 5,
      });
      final data = await DashboardRemoteDatasource(
        dio,
        (p) => p == 'prosthetic_cases.view',
      ).fetch();
      final p = data.insights.prosthetic!;
      expect(p.active, 7);
      expect(p.atLaboratory, 3);
      expect(p.returned, 2);
      expect(p.waitingForPlacement, 2);
      expect(p.placementsToday, 1);
      expect(p.placementsThisWeek, 4);
      expect(p.paymentsDue, 5);
    });

    test('a failed call is unavailable, not seven zeros', () async {
      stubBasics();
      stub('prosthetic-dashboard', fail: true);
      final data = await DashboardRemoteDatasource(
        dio,
        (p) => p == 'prosthetic_cases.view',
      ).fetch();
      expect(data.insights.prosthetic, isNull);
      expect(data.insights.unavailable, {'prosthetic'});
    });
  });

  group('releases and activity', () {
    test('counts cycles waiting for a release decision', () async {
      stubBasics();
      final data =
          await DashboardRemoteDatasource(dio, (p) => p == 'cycles.view')
              .fetch();
      expect(data.insights.awaitingRelease, 2);
    });

    test('activity is worded in French and names who did it', () async {
      stubBasics();
      final data =
          await DashboardRemoteDatasource(dio, (p) => p == 'audit.view')
              .fetch();
      final e = data.recentProcedures.single;
      expect(e.actor, 'Dr Martin');
      expect(e.label, isNot('cycle.released'));
      expect(e.label, isNotEmpty);
    });
  });
}
