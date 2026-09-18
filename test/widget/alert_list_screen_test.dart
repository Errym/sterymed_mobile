import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/features/alerts/data/repositories/alert_repository.dart';
import 'package:steriymed_mobile/features/alerts/presentation/bloc/alert_list_bloc.dart';
import 'package:steriymed_mobile/features/alerts/presentation/screens/alert_list_screen.dart';

import '../fixtures/alert_fixture.dart';
import '../helpers/pump_app.dart';

class MockAlertRepository extends Mock implements AlertRepository {}

void main() {
  late MockAlertRepository repo;

  setUp(() {
    repo = MockAlertRepository();
  });

  testWidgets('renders severity groups', (tester) async {
    when(() => repo.getActiveAlerts(
          forceRefresh: any(named: 'forceRefresh'),
        )).thenAnswer((_) async => [
              buildAlert(id: 'a1', severity: AlertSeverity.critical),
              buildAlert(id: 'a2', severity: AlertSeverity.warning),
              buildAlert(id: 'a3', severity: AlertSeverity.info),
            ]);

    await pumpApp(
      tester,
      BlocProvider(
        create: (_) => AlertListBloc(repo)..add(const LoadAlerts()),
        child: const AlertListScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Critique'), findsOneWidget);
    expect(find.text('Avertissement'), findsOneWidget);
    expect(find.text('Information'), findsOneWidget);
  });

  testWidgets('shows empty view when no alerts', (tester) async {
    when(() => repo.getActiveAlerts(
          forceRefresh: any(named: 'forceRefresh'),
        )).thenAnswer((_) async => []);

    await pumpApp(
      tester,
      BlocProvider(
        create: (_) => AlertListBloc(repo)..add(const LoadAlerts()),
        child: const AlertListScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Aucune alerte active'), findsOneWidget);
  });
}
