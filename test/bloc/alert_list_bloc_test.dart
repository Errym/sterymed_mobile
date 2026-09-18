import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/errors/api_exception.dart';
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
            )).thenAnswer((_) async => [buildAlert()]);
      },
      act: (b) => b.add(const LoadAlerts()),
      expect: () => [
        isA<AlertListState>()
            .having((s) => s.status, 'status', AlertListStatus.loading),
        isA<AlertListState>()
            .having((s) => s.status, 'status', AlertListStatus.success)
            .having((s) => s.alerts.length, 'alerts', 1),
      ],
    );

    blocTest<AlertListBloc, AlertListState>(
      'emits failure on error',
      build: () => AlertListBloc(repo),
      setUp: () {
        when(() => repo.getActiveAlerts(
              forceRefresh: any(named: 'forceRefresh'),
            )).thenThrow(const ApiException(
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
