import '../../../../core/router/route_names.dart';

/// Defines which routes are visible to which roles.
/// The pilot has two roles: `owner` (admin) and `staff`.
abstract final class RoleAwareNav {
  static const _staffHiddenRoutes = <String>{
    RouteNames.audit,
    RouteNames.settings,
  };

  static bool isVisible({
    required String role,
    required String routeName,
  }) {
    if (role == 'owner' || role == 'admin') return true;
    return !_staffHiddenRoutes.contains(routeName);
  }
}
