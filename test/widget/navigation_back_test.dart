// Back navigation: a screen above a tab must always have a way back, whether
// the person got there by tapping through (history exists) or by a deep link /
// restored session (no history). Regression for forms that stayed on screen
// after a successful save because they were opened with go() and had nothing
// to pop.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:steriymed_mobile/core/router/routes.dart';
import 'package:steriymed_mobile/core/utils/extensions/context_ext.dart';
import 'package:steriymed_mobile/shared/widgets/layout/app_appbar.dart';

GoRouter _router({String initial = Routes.stock}) {
  return GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: Routes.stock,
        builder: (c, s) => Scaffold(
          appBar: AppBar(title: const Text('Stock tab')),
          body: Column(
            children: [
              TextButton(
                onPressed: () => c.openRoute(Routes.stockIssue),
                child: const Text('open issue'),
              ),
            ],
          ),
        ),
      ),
      GoRoute(
        path: Routes.dashboard,
        builder: (c, s) => const Scaffold(body: Text('Dashboard')),
      ),
      GoRoute(
        path: Routes.stockIssue,
        builder: (c, s) => Scaffold(
          appBar: AppBar(
            title: const Text('Issue form'),
            leading: AppBackButton.maybe(c),
          ),
          body: TextButton(
            onPressed: () => c.popOrGo(Routes.stock),
            child: const Text('save'),
          ),
        ),
      ),
    ],
  );
}

Widget _app(GoRouter r) => MaterialApp.router(routerConfig: r);

void main() {
  group('route helpers', () {
    test('tabs are recognised, screens above them are not', () {
      expect(isTabRoute(Routes.stock), isTrue);
      expect(isTabRoute('${Routes.stock}?x=1'), isTrue);
      expect(isTabRoute(Routes.stockIssue), isFalse);
      expect(isTabRoute(Routes.cyclesDetail('1')), isFalse);
    });

    test('parent tab is where "back" lands without history', () {
      expect(parentTabOf(Routes.stockIssue), Routes.stock);
      expect(parentTabOf(Routes.cyclesDetail('1')), Routes.cycles);
      expect(parentTabOf('/app/labels/ABC/usage'), Routes.scanner);
      expect(parentTabOf('/app/purchases/1/receive'), Routes.dashboard);
    });
  });

  testWidgets('opened from the tab: back arrow and save both return to it', (
    tester,
  ) async {
    final r = _router();
    await tester.pumpWidget(_app(r));
    await tester.tap(find.text('open issue'));
    await tester.pumpAndSettle();
    expect(find.text('Issue form'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('Stock tab'), findsOneWidget);

    await tester.tap(find.text('open issue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('save'));
    await tester.pumpAndSettle();
    expect(find.text('Stock tab'), findsOneWidget);
  });

  testWidgets('deep link with no history: back arrow still exists and works', (
    tester,
  ) async {
    final r = _router(initial: Routes.stockIssue);
    await tester.pumpWidget(_app(r));
    await tester.pumpAndSettle();
    expect(find.text('Issue form'), findsOneWidget);
    expect(r.canPop(), isFalse);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget,
        reason: 'no history must not mean no way back');

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('Stock tab'), findsOneWidget);
  });

  testWidgets('saving a form that has no history leaves it (no stuck form)', (
    tester,
  ) async {
    final r = _router(initial: Routes.stockIssue);
    await tester.pumpWidget(_app(r));
    await tester.pumpAndSettle();
    await tester.tap(find.text('save'));
    await tester.pumpAndSettle();
    expect(find.text('Issue form'), findsNothing);
    expect(find.text('Stock tab'), findsOneWidget);
  });

  testWidgets('a tab root shows no back arrow', (tester) async {
    final r = GoRouter(
      initialLocation: Routes.stock,
      routes: [
        GoRoute(
          path: Routes.stock,
          builder: (c, s) => Scaffold(
            appBar: AppBar(
              title: const Text('Stock tab'),
              leading: AppBackButton.maybe(c),
            ),
          ),
        ),
      ],
    );
    await tester.pumpWidget(_app(r));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.arrow_back), findsNothing);
  });
}
