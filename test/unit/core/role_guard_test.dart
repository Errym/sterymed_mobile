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

    test('exact routes map to their real backend permission', () {
      const expected = {
        Routes.cyclesCreate: 'cycles.manage',
        Routes.stockIssue: 'inventory.manage',
        Routes.stockAdjust: 'inventory.manage',
        Routes.stockTransfer: 'inventory.manage',
        Routes.audit: 'audit.view',
        Routes.sites: 'sites.view',
        Routes.nonConformities: 'non_conformities.view',
        Routes.dataExports: 'data_exports.manage',
        Routes.devices: 'devices.view',
        Routes.products: 'products.view',
        Routes.suppliers: 'suppliers.view',
        Routes.purchases: 'purchasing.view',
        Routes.patients: 'patients.view',
        Routes.dluRules: 'evidence_settings.manage',
      };
      expected.forEach((route, permission) {
        expect(
          RoleGuard.requiredPermissionFor(route),
          permission,
          reason: '$route should require $permission',
        );
      });
    });

    test('routes with no backend gate stay open (Accueil, Plus, Team, ...)',
        () {
      const ungated = [
        Routes.dashboard,
        Routes.settings,
        Routes.about,
        Routes.sync,
        Routes.team,
      ];
      for (final route in ungated) {
        expect(RoleGuard.requiredPermissionFor(route), isNull);
      }
    });

    test('a parameterized cycle route requires cycles.view, not the list\'s',
        () {
      expect(
        RoleGuard.requiredPermissionFor('/app/cycles/abc-123'),
        'cycles.view',
      );
      expect(
        RoleGuard.requiredPermissionFor('/app/cycles/abc-123/items'),
        'cycles.view',
      );
      expect(
        RoleGuard.requiredPermissionFor('/app/cycles/abc-123/control-tests'),
        'cycles.view',
      );
      expect(
        RoleGuard.requiredPermissionFor('/app/cycles/abc-123/attachments'),
        'cycles.view',
      );
    });

    test('cycle release requires cycles.release, not cycles.manage', () {
      expect(
        RoleGuard.requiredPermissionFor('/app/cycles/abc-123/release'),
        'cycles.release',
      );
      expect(
        RoleGuard.isAllowed(
          route: '/app/cycles/abc-123/release',
          hasPermission: (p) => p == 'cycles.manage',
        ),
        isFalse,
        reason: 'cycles.manage alone must not unlock release',
      );
    });

    test('purchase receipt requires purchasing.manage, detail only view', () {
      expect(
        RoleGuard.requiredPermissionFor('/app/purchases/po-1/receive'),
        'purchasing.manage',
      );
      expect(
        RoleGuard.requiredPermissionFor('/app/purchases/po-1'),
        'purchasing.view',
      );
    });

    test('recording label usage requires usages.manage, not just labels.view',
        () {
      expect(
        RoleGuard.requiredPermissionFor('/app/labels/CODE1/usage'),
        'usages.manage',
      );
      expect(
        RoleGuard.requiredPermissionFor('/app/labels/CODE1'),
        'labels.view',
      );
      expect(
        RoleGuard.requiredPermissionFor('/app/labels/CODE1/blocked'),
        'labels.view',
      );
      expect(
        RoleGuard.isAllowed(
          route: '/app/labels/CODE1/usage',
          hasPermission: (p) => p == 'labels.view',
        ),
        isFalse,
        reason: 'labels.view alone must not unlock recording usage',
      );
    });

    test('device detail requires devices.view', () {
      expect(
        RoleGuard.requiredPermissionFor('/app/devices/dev-1'),
        'devices.view',
      );
    });
  });
}
