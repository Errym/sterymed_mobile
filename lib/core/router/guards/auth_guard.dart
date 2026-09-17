import '../route_names.dart';

abstract final class AuthGuard {
  static const publicRoutes = <String>{
    RouteNames.splash,
    RouteNames.login,
    RouteNames.register,
    RouteNames.cameraPermission,
  };

  static bool isPublic(String routeName) => publicRoutes.contains(routeName);
}
