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
        when(() => repo.getActiveAlerts(forceRefresh: any(named: 'forceRefresh')))
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
        when(() => repo.getActiveAlerts(forceRefresh: any(named: 'forceRefresh')))
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
        when(() => repo.loadMore('cursor-1')).thenAnswer(
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
        verify(() => repo.loadMore('cursor-1')).called(1);
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
        verifyNever(() => repo.loadMore(any()));
      },
    );

    blocTest<AlertListBloc, AlertListState>(
      'resolve succeeds — alert removed from the list, stays removed',
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
            .having((s) => s.alerts.map((a) => a.id), 'alerts', ['a2']),
      ],
    );

    blocTest<AlertListBloc, AlertListState>(
      'resolve fails — alert restored and error surfaced',
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
        // Optimistic removal.
        isA<AlertListState>()
            .having((s) => s.alerts.map((a) => a.id), 'alerts', ['a2']),
        // Restored with the error surfaced.
        isA<AlertListState>()
            .having((s) => s.alerts.map((a) => a.id), 'alerts', ['a1', 'a2'])
            .having((s) => s.error, 'error', 'Erreur serveur.'),
      ],
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
