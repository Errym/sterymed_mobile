abstract final class RoleGuard {
  static const adminOnly = <String>{};

  static bool isAllowed({required String role, required String routeName}) {
    if (role == 'admin') return true;
    return !adminOnly.contains(routeName);
  }
}
