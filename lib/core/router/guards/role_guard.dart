import '../routes.dart';

/// Maps a route to the permission its data requires. Backed by the
/// tenant's real spatie/permission grants (see steriqore's
/// SeedTenantRolesAction — cycles.view/manage/release, inventory.view/
/// manage, purchasing.view/manage, labels.view/manage, usages.view/manage,
/// devices.view/manage, products.view/manage, suppliers.view/manage,
/// sites.view/manage, audit.view, non_conformities.view/manage,
/// data_exports.manage, patients.view/manage, evidence_settings.manage
/// (owner-only)), exposed on UserData/SessionStore since the
/// /v1/auth/login and /v1/me responses started returning `permissions`.
///
/// A route with no entry here (Accueil, Plus/Settings, About, Sync, Team)
/// is always allowed — Accueil degrades gracefully with no permissions
/// (each of its aggregate calls fails independently and is swallowed),
/// Settings only ever calls /v1/me, and the backend has no per-role
/// permission gating who can *view* the team list (only invite/disable,
/// gated at the action level inside the screen).
abstract final class RoleGuard {
  static const _exactPermission = <String, String>{
    Routes.scanner: 'labels.view',
    Routes.cycles: 'cycles.view',
    Routes.cyclesCreate: 'cycles.manage',
    Routes.stock: 'inventory.view',
    Routes.stockIssue: 'inventory.manage',
    Routes.stockAdjust: 'inventory.manage',
    Routes.stockTransfer: 'inventory.manage',
    Routes.alerts: 'alerts.view',
    Routes.audit: 'audit.view',
    Routes.sites: 'sites.view',
    Routes.nonConformities: 'non_conformities.view',
    Routes.dataExports: 'data_exports.manage',
    Routes.devices: 'devices.view',
    Routes.products: 'products.view',
    Routes.suppliers: 'suppliers.view',
    Routes.purchases: 'purchasing.view',
    Routes.patients: 'patients.view',
    // Owner-only per steriqore's SeedTenantRolesAction: DLU rules are one
    // of the two "evidence-affecting" sections (with label format) the
    // backend never grants to a non-owner admin.
    Routes.dluRules: 'evidence_settings.manage',
  };

  /// Parameterized routes (`/app/cycles/:id`, ...) can't be exact-matched.
  /// Checked in order, most specific first, after [_exactPermission] finds
  /// no hit — a suffix-specific rule must precede its prefix-only sibling.
  static const _prefixRules = <(String prefix, String? suffix, String permission)>[
    ('/app/cycles/', '/release', 'cycles.release'),
    ('/app/cycles/', null, 'cycles.view'),
    ('/app/purchases/', '/receive', 'purchasing.manage'),
    ('/app/purchases/', null, 'purchasing.view'),
    ('/app/labels/', '/usage', 'usages.manage'),
    ('/app/labels/', null, 'labels.view'),
    ('/app/devices/', null, 'devices.view'),
  ];

  static String? requiredPermissionFor(String route) {
    final exact = _exactPermission[route];
    if (exact != null) return exact;

    for (final (prefix, suffix, permission) in _prefixRules) {
      if (!route.startsWith(prefix)) continue;
      if (suffix == null || route.endsWith(suffix)) return permission;
    }
    return null;
  }

  static bool isAllowed({
    required String route,
    required bool Function(String permission) hasPermission,
  }) {
    final required = requiredPermissionFor(route);
    if (required == null) return true;
    return hasPermission(required);
  }
}
