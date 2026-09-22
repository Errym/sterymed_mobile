import 'package:flutter_test/flutter_test.dart';
import 'package:steriymed_mobile/core/router/guards/role_guard.dart';
import 'package:steriymed_mobile/core/router/routes.dart';

void main() {
  group('RoleGuard', () {
    test('routes with no permission requirement are always allowed', () {
      expect(
        RoleGuard.isAllowed(
          route: Routes.dashboard,
          hasPermission: (_) => false,
        ),
        isTrue,
      );
      expect(RoleGuard.requiredPermissionFor(Routes.dashboard), isNull);
    });

    test('cycles tab requires cycles.view', () {
      expect(RoleGuard.requiredPermissionFor(Routes.cycles), 'cycles.view');
      expect(
        RoleGuard.isAllowed(
          route: Routes.cycles,
          hasPermission: (p) => p == 'cycles.view',
        ),
        isTrue,
      );
      expect(
        RoleGuard.isAllowed(
          route: Routes.cycles,
          hasPermission: (_) => false,
        ),
        isFalse,
      );
    });

    test('a user with zero permissions is blocked from every gated tab',
        () {
      const gated = [Routes.scanner, Routes.cycles, Routes.stock, Routes.alerts];
      for (final route in gated) {
        expect(
          RoleGuard.isAllowed(route: route, hasPermission: (_) => false),
          isFalse,
          reason: '$route should require a permission',
        );
      }
    });
  });
}
