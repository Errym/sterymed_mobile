import 'dart:async';

import 'package:flutter/foundation.dart';

/// Bridges a `Stream` (here, `AuthBloc`'s own state stream) to a
/// `Listenable` GoRouter's `refreshListenable` can watch — without this,
/// GoRouter only re-evaluates its `redirect` callback on an actual
/// navigation attempt, not the instant the underlying auth state changes.
/// A real 401 on a background screen would otherwise leave the user
/// stranded on that screen until they happened to navigate somewhere
/// else. Standard go_router pattern, not a new dependency (just
/// `dart:async` + `ChangeNotifier`, already-imported packages).
class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen(
          (_) => notifyListeners(),
        );
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
