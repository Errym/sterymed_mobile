import '../routes.dart';

/// Maps a top-level (bottom-nav) route to the permission its data requires.
/// Backed by the tenant's real spatie/permission grants, exposed on
/// UserData/SessionStore since the /v1/auth/login and /v1/me responses
/// started returning `permissions`. A route with no entry here (Accueil,
/// Plus/Settings) is always allowed — Accueil degrades gracefully with no
/// permissions (each of its aggregate calls fails independently and is
/// swallowed), and Settings only ever calls /v1/me.
abstract final class RoleGuard {
  static const _requiredPermission = <String, String>{
    Routes.scanner: 'labels.view',
    Routes.cycles: 'cycles.view',
    Routes.stock: 'inventory.view',
    Routes.alerts: 'alerts.view',
  };

  static String? requiredPermissionFor(String route) =>
      _requiredPermission[route];

  static bool isAllowed({
    required String route,
    required bool Function(String permission) hasPermission,
  }) {
    final required = _requiredPermission[route];
    if (required == null) return true;
    return hasPermission(required);
  }
}
