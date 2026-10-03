import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/errors/api_exception.dart';
import 'package:steriymed_mobile/core/network/cursor_page.dart';
import 'package:steriymed_mobile/features/alerts/data/models/alert_data.dart';
import 'package:steriymed_mobile/features/alerts/data/repositories/alert_repository.dart';
import 'package:steriymed_mobile/features/alerts/presentation/bloc/alert_list_bloc.dart';

import '../fixtures/alert_fixture.dart';

class MockAlertRepository extends Mock implements AlertRepository {}

void main() {
  late MockAlertRepository repo;

  setUp(() {
    repo = MockAlertRepository();
  });

  group('AlertListBloc', () {
    blocTest<AlertListBloc, AlertListState>(
      'loads alerts',
      build: () => AlertListBloc(repo),
      setUp: () {
        when(() => repo.getActiveAlerts(
            forceRefresh: any(named: 'forceRefresh'),
            type: any(named: 'type'),
            state: any(named: 'state'),
          ))
            .thenAnswer((_) async => CursorPage(items: [buildAlert()]));
      },
      act: (b) => b.add(const LoadAlerts()),
      expect: () => [
        isA<AlertListState>()
            .having((s) => s.status, 'status', AlertListStatus.loading),
        isA<AlertListState>()
            .having((s) => s.status, 'status', AlertListStatus.success)
            .having((s) => s.alerts.length, 'alerts', 1)
            .having((s) => s.hasMore, 'hasMore', false),
      ],
    );

    blocTest<AlertListBloc, AlertListState>(
      'emits failure on error',
      build: () => AlertListBloc(repo),
      setUp: () {
        when(() => repo.getActiveAlerts(
            forceRefresh: any(named: 'forceRefresh'),
            type: any(named: 'type'),
            state: any(named: 'state'),
          ))
            .thenThrow(const ApiException(
          code: 'server_error',
          message: 'Erreur serveur.',
        ));
      },
      act: (b) => b.add(const LoadAlerts()),
      expect: () => [
        isA<AlertListState>()
            .having((s) => s.status, 'status', AlertListStatus.loading),
        isA<AlertListState>()
            .having((s) => s.status, 'status', AlertListStatus.failure),
      ],
    );

    blocTest<AlertListBloc, AlertListState>(
      'loads the next page and appends it on LoadMoreAlerts',
      build: () => AlertListBloc(repo),
      seed: () => AlertListState(
        status: AlertListStatus.success,
        alerts: [buildAlert(id: 'a1')],
        nextCursor: 'cursor-1',
      ),
      setUp: () {
        when(() => repo.loadMore('cursor-1',
            type: any(named: 'type'), state: any(named: 'state'))).thenAnswer(
          (_) async => CursorPage(items: [buildAlert(id: 'a2')]),
        );
      },
      act: (b) => b.add(const LoadMoreAlerts()),
      expect: () => [
        isA<AlertListState>()
            .having((s) => s.isLoadingMore, 'isLoadingMore', true),
        isA<AlertListState>()
            .having((s) => s.alerts.length, 'alerts', 2)
            .having((s) => s.hasMore, 'hasMore', false)
            .having((s) => s.isLoadingMore, 'isLoadingMore', false),
      ],
      verify: (_) {
        verify(() => repo.loadMore('cursor-1',
            type: any(named: 'type'), state: any(named: 'state'))).called(1);
      },
    );

    blocTest<AlertListBloc, AlertListState>(
      'LoadMoreAlerts is a no-op when there is no next cursor',
      build: () => AlertListBloc(repo),
      seed: () => AlertListState(
        status: AlertListStatus.success,
        alerts: [buildAlert()],
      ),
      act: (b) => b.add(const LoadMoreAlerts()),
      expect: () => <AlertListState>[],
      verify: (_) {
        verifyNever(() => repo.loadMore(any(),
            type: any(named: 'type'), state: any(named: 'state')));
      },
    );

    blocTest<AlertListBloc, AlertListState>(
      'resolve succeeds: spinner, then the alert leaves and a success notice shows',
      build: () => AlertListBloc(repo),
      seed: () => AlertListState(
        status: AlertListStatus.success,
        alerts: [buildAlert(id: 'a1'), buildAlert(id: 'a2')],
      ),
      setUp: () {
        when(() => repo.resolveAlert('a1')).thenAnswer((_) async {});
      },
      act: (b) => b.add(const ResolveAlert('a1')),
      expect: () => [
        isA<AlertListState>()
            .having((s) => s.resolving, 'resolving', {'a1'})
            // Not removed until the server answered.
            .having((s) => s.alerts.length, 'alerts', 2),
        isA<AlertListState>()
            .having((s) => s.alerts.map((a) => a.id), 'alerts', ['a2'])
            .having((s) => s.resolving, 'resolving', isEmpty)
            .having((s) => s.notice?.isError, 'isError', false),
      ],
    );

    blocTest<AlertListBloc, AlertListState>(
      'resolve fails: the alert stays and the real reason is surfaced',
      build: () => AlertListBloc(repo),
      seed: () => AlertListState(
        status: AlertListStatus.success,
        alerts: [buildAlert(id: 'a1'), buildAlert(id: 'a2')],
      ),
      setUp: () {
        when(() => repo.resolveAlert('a1')).thenThrow(const ApiException(
          code: 'server_error',
          message: 'Erreur serveur.',
        ));
      },
      act: (b) => b.add(const ResolveAlert('a1')),
      expect: () => [
        isA<AlertListState>().having((s) => s.resolving, 'resolving', {'a1'}),
        isA<AlertListState>()
            .having((s) => s.alerts.map((a) => a.id), 'alerts', ['a1', 'a2'])
            .having((s) => s.resolving, 'resolving', isEmpty)
            .having((s) => s.notice?.isError, 'isError', true)
            .having((s) => s.notice?.message, 'message', isNotEmpty),
      ],
    );

    blocTest<AlertListBloc, AlertListState>(
      'a 409 (already resolved by someone else) counts as resolved',
      build: () => AlertListBloc(repo),
      seed: () => AlertListState(
        status: AlertListStatus.success,
        alerts: [buildAlert(id: 'a1')],
      ),
      setUp: () {
        when(() => repo.resolveAlert('a1')).thenThrow(const ApiException(
          code: 'ALERT_ALREADY_RESOLVED',
          message: 'This alert has already been resolved.',
          statusCode: 409,
        ));
      },
      act: (b) => b.add(const ResolveAlert('a1')),
      expect: () => [
        isA<AlertListState>().having((s) => s.resolving, 'resolving', {'a1'}),
        isA<AlertListState>()
            .having((s) => s.alerts, 'alerts', isEmpty)
            .having((s) => s.notice?.message, 'message',
                'Cette alerte était déjà résolue.'),
      ],
    );

    blocTest<AlertListBloc, AlertListState>(
      'a double tap on resolve sends one request',
      build: () => AlertListBloc(repo),
      seed: () => AlertListState(
        status: AlertListStatus.success,
        alerts: [buildAlert(id: 'a1')],
      ),
      setUp: () {
        when(() => repo.resolveAlert('a1')).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });
      },
      act: (b) {
        b.add(const ResolveAlert('a1'));
        b.add(const ResolveAlert('a1'));
      },
      wait: const Duration(milliseconds: 80),
      verify: (_) => verify(() => repo.resolveAlert('a1')).called(1),
    );

    blocTest<AlertListBloc, AlertListState>(
      'filtering by type asks the server for that type and keeps the filter',
      build: () => AlertListBloc(repo),
      setUp: () {
        when(() => repo.getActiveAlerts(
              forceRefresh: any(named: 'forceRefresh'),
              type: 'near_expiry',
              state: 'open',
            )).thenAnswer((_) async => CursorPage(
              items: [buildAlert(id: 'x', type: 'near_expiry')],
            ));
      },
      act: (b) =>
          b.add(const FilterAlerts(type: 'near_expiry', state: 'open')),
      expect: () => [
        isA<AlertListState>()
            .having((s) => s.typeFilter, 'type', 'near_expiry')
            .having((s) => s.status, 'status', AlertListStatus.loading),
        isA<AlertListState>()
            .having((s) => s.alerts.single.type, 'type', 'near_expiry')
            .having((s) => s.typeFilter, 'type', 'near_expiry'),
      ],
    );

    blocTest<AlertListBloc, AlertListState>(
      'the resolved filter sends state=resolved; "all" sends no state',
      build: () => AlertListBloc(repo),
      setUp: () {
        when(() => repo.getActiveAlerts(
              forceRefresh: any(named: 'forceRefresh'),
              type: any(named: 'type'),
              state: any(named: 'state'),
            )).thenAnswer((_) async => const CursorPage(items: []));
      },
      act: (b) async {
        b.add(const FilterAlerts(state: 'resolved'));
        await Future<void>.delayed(const Duration(milliseconds: 10));
        b.add(const FilterAlerts(state: null));
      },
      wait: const Duration(milliseconds: 50),
      verify: (_) {
        verify(() => repo.getActiveAlerts(
              forceRefresh: any(named: 'forceRefresh'),
              type: null,
              state: 'resolved',
            )).called(1);
        verify(() => repo.getActiveAlerts(
              forceRefresh: any(named: 'forceRefresh'),
              type: null,
              state: null,
            )).called(1);
      },
    );

    blocTest<AlertListBloc, AlertListState>(
      'load more keeps the filters of the first page',
      build: () => AlertListBloc(repo),
      seed: () => AlertListState(
        status: AlertListStatus.success,
        alerts: [buildAlert(id: 'a1')],
        nextCursor: 'c1',
        typeFilter: 'low_stock',
        stateFilter: 'resolved',
      ),
      setUp: () {
        when(() => repo.loadMore('c1', type: 'low_stock', state: 'resolved'))
            .thenAnswer((_) async => const CursorPage(items: []));
      },
      act: (b) => b.add(const LoadMoreAlerts()),
      verify: (_) => verify(
              () => repo.loadMore('c1', type: 'low_stock', state: 'resolved'))
          .called(1),
    );

    test('severity grouping', () {
      final state = AlertListState(
        alerts: [
          buildAlert(id: 'a1', severity: AlertSeverity.critical),
          buildAlert(id: 'a2', severity: AlertSeverity.warning),
          buildAlert(id: 'a3', severity: AlertSeverity.warning),
          buildAlert(id: 'a4', severity: AlertSeverity.info),
        ],
      );
      expect(state.criticalAlerts.length, 1);
      expect(state.warningAlerts.length, 2);
      expect(state.infoAlerts.length, 1);
    });
  });
}
