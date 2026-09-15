import '../route_names.dart';

abstract final class AuthGuard {
  static const publicRoutes = <String>{
    RouteNames.splash,
    RouteNames.onboarding,
    RouteNames.login,
  };

  static bool isPublic(String routeName) => publicRoutes.contains(routeName);
}
