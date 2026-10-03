import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router/routes.dart';

extension BuildContextX on BuildContext {
  Size get screenSize => MediaQuery.of(this).size;
  bool get isTablet => screenSize.width >= 700;
  void unfocus() => FocusScope.of(this).unfocus();
}

/// The six places the bottom bar (and the "Plus" menu) can switch to. Anything
/// else is a screen *above* one of them (a detail, a form, a list reached from
/// a menu) and must be pushed so the person can come back.
const _tabRoots = <String>{
  Routes.dashboard,
  Routes.scanner,
  Routes.cycles,
  Routes.alerts,
  Routes.settings,
  Routes.stock,
};

/// Whether [route] (a path, optionally with a query) is a bottom-bar tab.
bool isTabRoute(String route) => _tabRoots.contains(Uri.parse(route).path);

/// The tab a screen lives under, used as the "back" target when there is no
/// history to pop (deep link, restored session). Falls back to the dashboard.
String parentTabOf(String location) {
  final path = Uri.parse(location).path;
  for (final tab in _tabRoots) {
    if (tab == Routes.dashboard) continue;
    if (path == tab || path.startsWith('$tab/')) return tab;
  }
  if (path.startsWith('/app/labels')) return Routes.scanner;
  return Routes.dashboard;
}

extension NavigationX on BuildContext {
  /// Opens [route] the way a person expects: tabs replace each other, every
  /// other screen is pushed on top so the back arrow and Android back work.
  Future<T?> openRoute<T extends Object?>(String route, {Object? extra}) {
    if (isTabRoute(route)) {
      go(route, extra: extra);
      return Future<T?>.value();
    }
    return push<T>(route, extra: extra);
  }

  /// Leaves the current screen: pops when there is history, otherwise goes to
  /// [fallback] (default: the tab this screen belongs to). Never throws and
  /// never leaves a finished form on screen.
  void popOrGo([String? fallback]) {
    if (canPop()) {
      pop();
      return;
    }
    final here = GoRouterState.of(this).uri.toString();
    go(fallback ?? parentTabOf(here));
  }
}
