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
/// A route with no entry here (Accueil, Plus/Settings, About, Sync) is
/// always allowed — Accueil degrades gracefully with no permissions
/// (each of its aggregate calls fails independently and is swallowed),
/// Settings only ever calls /v1/me. Team (added 2026-09-24 along with the
/// `GET /v1/members` endpoint itself — see BUG-011) is gated on
/// `invitations.create`, the same permission the web app's TeamController
/// uses for its own index action — there's no separate "view team" grant
/// in the permission model.
abstract final class RoleGuard {
  static const _exactPermission = <String, String>{
    Routes.scanner: 'labels.view',
    Routes.team: 'invitations.create',
    Routes.cycles: 'cycles.view',
    Routes.cyclesCreate: 'cycles.manage',
    Routes.stock: 'inventory.view',
    Routes.batches: 'inventory.view',
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
    // Verified against EvidenceSearchController.php → LabelUsagePolicy's
    // viewAny (`usages.view`, universal) — a separate, more sensitive
    // `export` ability (`exports.manage`) exists for a bulk-export action
    // this screen doesn't build yet.
    Routes.evidenceSearch: 'usages.view',
    // Corrected 2026-09-26: verified directly against DluRuleController.php
    // (`$this->authorize('viewAny', DluRule::class)`) and DluRulePolicy.php
    // — viewAny is `labels.view` (universal), create/update/delete are
    // `labels.manage` (owner/admin/stock_manager). `evidence_settings.manage`
    // is never referenced by any API controller, only by the web-only
    // Tenancy\PracticeSettingsController — it has no relevance to this
    // route and was gating it far more restrictively than the backend
    // actually does. In-screen create/edit/delete actions on
    // dlu_rules_screen.dart correctly check `labels.manage` themselves.
    Routes.dluRules: 'labels.view',
    // ADR 0011 — Prosthetic Work Tracking. `prosthetic_cases.view` is
    // universal (everyone can see the module); create and laboratory
    // management need `prosthetic_cases.manage` (owner/admin/practitioner
    // only) — in-screen actions on the case list/detail handle the
    // finer clinical-vs-payment split themselves.
    Routes.prosthetic: 'prosthetic_cases.view',
    Routes.prostheticCreate: 'prosthetic_cases.manage',
    Routes.prostheticWaitingPlacement: 'prosthetic_cases.view',
    Routes.prostheticLaboratories: 'prosthetic_cases.manage',
  };

  /// Parameterized routes (`/app/cycles/:id`, ...) can't be exact-matched.
  /// Checked in order, most specific first, after [_exactPermission] finds
  /// no hit — a suffix-specific rule must precede its prefix-only sibling.
  static const _prefixRules = <(String prefix, String? suffix, String permission)>[
    ('/app/cycles/', '/release', 'cycles.release'),
    ('/app/cycles/', null, 'cycles.view'),
    ('/app/purchases/', '/receive', 'purchasing.manage'),
    ('/app/purchases/suppliers/', null, 'suppliers.view'),
    ('/app/purchases/', null, 'purchasing.view'),
    ('/app/labels/', '/usage', 'usages.manage'),
    ('/app/labels/', null, 'labels.view'),
    ('/app/devices/', null, 'devices.view'),
    ('/app/prosthetic/', null, 'prosthetic_cases.view'),
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
