import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/network/cursor_page.dart';
import 'package:steriymed_mobile/core/theme/typography.dart';
import 'package:steriymed_mobile/features/alerts/data/models/alert_data.dart';
import 'package:steriymed_mobile/features/alerts/data/repositories/alert_repository.dart';
import 'package:steriymed_mobile/features/alerts/presentation/bloc/alert_list_bloc.dart';
import 'package:steriymed_mobile/features/alerts/presentation/screens/alert_list_screen.dart';
import '../fixtures/alert_fixture.dart';
import '../helpers/pump_app.dart';
import '../mocks/mock_repositories.dart';

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

  setUp(() {
    repo = MockAlertRepository();
  });

  testWidgets('renders severity groups', (tester) async {
    when(() => repo.getActiveAlerts(forceRefresh: any(named: 'forceRefresh')))
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
  });

  testWidgets('shows empty view when no alerts', (tester) async {
    when(() => repo.getActiveAlerts(forceRefresh: any(named: 'forceRefresh')))
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
}
