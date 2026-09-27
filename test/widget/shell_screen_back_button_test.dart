// Regression test for the hardware-back-button-exits-the-app bug —
// docs/DEVICE_TEST_LOG.md's "Known device-testing issue", reproduced
// repeatedly on a real device from the Cycles/Purchase Orders/Suppliers
// lists. Root cause: BottomNavBar switches tabs with context.go(), which
// replaces the whole navigation stack, so a top-level tab has nothing to
// pop — without a PopScope, Android's back button falls through and
// exits the app. ShellScreen now intercepts that: canPop is only true on
// the Accueil (dashboard) tab, otherwise back navigates to dashboard.
//
// Simulates the real GoRouter navigation stack (a ShellRoute wrapping two
// tab routes) rather than pumping ShellScreen in isolation, since the fix
// depends on real go_router stack-replacement behavior, not just widget
// structure.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/router/routes.dart';
import 'package:steriymed_mobile/core/storage/session_store.dart';
import 'package:steriymed_mobile/core/sync/sync_status.dart';
import 'package:steriymed_mobile/core/sync/sync_status_cubit.dart';
import 'package:steriymed_mobile/features/shell/presentation/screens/shell_screen.dart';

class MockSessionStore extends Mock implements SessionStore {}

class MockSyncStatusCubit extends MockCubit<SyncStatus>
    implements SyncStatusCubit {}

void main() {
  late MockSessionStore session;
  late MockSyncStatusCubit syncStatusCubit;

  setUp(() {
    session = MockSessionStore();
    when(() => session.hasPermission(any())).thenReturn(true);
    if (GetIt.instance.isRegistered<SessionStore>()) {
      GetIt.instance.unregister<SessionStore>();
    }
    GetIt.instance.registerSingleton<SessionStore>(session);

    syncStatusCubit = MockSyncStatusCubit();
    when(() => syncStatusCubit.state).thenReturn(const SyncStatus());
  });

  tearDown(() {
    if (GetIt.instance.isRegistered<SessionStore>()) {
      GetIt.instance.unregister<SessionStore>();
    }
  });

  GoRouter buildRouter() {
    return GoRouter(
      initialLocation: Routes.dashboard,
      routes: [
        ShellRoute(
          builder: (context, state, child) => BlocProvider<SyncStatusCubit>.value(
            value: syncStatusCubit,
            child: ShellScreen(child: child),
          ),
          routes: [
            GoRoute(
              path: Routes.dashboard,
              builder: (_, __) => const Text('DASHBOARD_SCREEN'),
            ),
            GoRoute(
              path: Routes.cycles,
              builder: (_, __) => const Text('CYCLES_SCREEN'),
            ),
          ],
        ),
      ],
    );
  }

  testWidgets(
      'back button on a non-dashboard tab returns to dashboard instead of exiting',
      (tester) async {
    final router = buildRouter();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    router.go(Routes.cycles);
    await tester.pumpAndSettle();
    expect(find.text('CYCLES_SCREEN'), findsOneWidget);

    final popScope = tester.widget<PopScope<Object?>>(find.byType(PopScope<Object?>));
    expect(popScope.canPop, isFalse,
        reason: 'a non-dashboard tab must not let the system pop (which '
            'would exit the app) — it must be intercepted instead');

    popScope.onPopInvokedWithResult!(false, null);
    await tester.pumpAndSettle();

    expect(find.text('DASHBOARD_SCREEN'), findsOneWidget,
        reason: 'intercepted back press should navigate to the dashboard tab');
  });

  testWidgets('back button on the dashboard tab is allowed to pop (exit)',
      (tester) async {
    final router = buildRouter();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('DASHBOARD_SCREEN'), findsOneWidget);

    final popScope = tester.widget<PopScope<Object?>>(find.byType(PopScope<Object?>));
    expect(popScope.canPop, isTrue,
        reason: 'on the Accueil tab, back should behave normally (exit '
            'the app), matching standard Android convention');
  });
}
