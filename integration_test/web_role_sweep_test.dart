// Journey R: all six backend roles sign in for real, then visit every screen.
// For each (role, screen): no frame exception, and the screen opens exactly
// when the server granted the permission that screen needs (otherwise the
// guard keeps the user away). Direct URL access is covered because we jump
// straight to the path, as a deep link would.
//
//   python scripts/seed_web_journeys.py
//   scripts/run_web_journeys.sh web_role_sweep_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:steriymed_mobile/core/router/guards/role_guard.dart';

import 'support/web_env.dart';

/// Screens reachable without an id. Expected access comes from RoleGuard's
/// permission for the path, checked against what the server granted this role.
const _screens = <String>[
  '/app/dashboard',
  '/app/scanner',
  '/app/cycles',
  '/app/cycles/create',
  '/app/alerts',
  '/app/settings',
  '/app/stock',
  '/app/stock/issue',
  '/app/stock/adjust',
  '/app/stock/transfer',
  '/app/inventory',
  '/app/batches',
  '/app/patients',
  '/app/audit',
  '/app/team',
  '/app/sites',
  '/app/non-conformities',
  '/app/data-exports',
  '/app/evidence-search',
  '/app/sync',
  '/app/about',
  '/app/catalog/products',
  '/app/purchases/suppliers',
  '/app/purchases',
  '/app/devices',
  '/app/dlu-rules',
  '/app/prosthetic',
  '/app/prosthetic/create',
  '/app/prosthetic/waiting-placement',
  '/app/prosthetic/laboratories',
];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('six roles open every screen they are granted, and only those', (
    tester,
  ) async {
    await launchApp(tester);
    final report = <String>[];

    for (final role in WebEnv.roles.keys) {
      await signIn(tester, role);
      expectNoFrameError(tester, 'dashboard as $role');

      for (final path in _screens) {
        // ignore: avoid_print
        print('SWEEP $role $path');
        goTo(tester, path);
        await settle(tester, 2.5);
        expectNoFrameError(tester, '$path as $role');

        final required = RoleGuard.requiredPermissionFor(path);
        final allowed = required == null || can(required);
        final landed = currentPath(tester);
        if (allowed) {
          expect(landed, path,
              reason: '$role holds ${required ?? "no permission"} so $path '
                  'must open, but the app is on $landed');
        } else {
          expect(landed, isNot(path),
              reason: '$role lacks $required so $path must stay closed');
        }
        report.add('$role $path ${allowed ? "open" : "blocked"}');
      }
      await signOut(tester);
    }
    // ignore: avoid_print
    print('ROLE_SWEEP_OK ${report.length} checks');
  });
}
