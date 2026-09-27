// The 401 → login redirect chain, router-bridge half: GoRouterRefreshStream
// is what makes a background AuthSessionExpired (see auth_bloc_test.dart)
// force GoRouter to re-evaluate `redirect` immediately, instead of only on
// the user's next manual navigation — see the class's own doc comment for
// why that distinction matters.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:steriymed_mobile/core/router/go_router_refresh_stream.dart';

void main() {
  test('does not notify until the stream actually emits', () async {
    final controller = StreamController<int>.broadcast();
    addTearDown(controller.close);

    var notifyCount = 0;
    final refresh = GoRouterRefreshStream(controller.stream)
      ..addListener(() => notifyCount++);
    addTearDown(refresh.dispose);

    await Future<void>.delayed(Duration.zero);
    expect(notifyCount, 0);
  });

  test('notifies listeners every time the stream emits', () async {
    final controller = StreamController<String>.broadcast();
    addTearDown(controller.close);

    var notifyCount = 0;
    final refresh = GoRouterRefreshStream(controller.stream)
      ..addListener(() => notifyCount++);
    addTearDown(refresh.dispose);

    controller.add('AuthUnauthenticated');
    await Future<void>.delayed(Duration.zero);
    expect(notifyCount, 1);

    controller.add('AuthAuthenticated');
    await Future<void>.delayed(Duration.zero);
    expect(notifyCount, 2);
  });

  test('stops notifying after dispose', () async {
    final controller = StreamController<int>.broadcast();
    addTearDown(controller.close);

    var notifyCount = 0;
    final refresh = GoRouterRefreshStream(controller.stream)
      ..addListener(() => notifyCount++);

    refresh.dispose();
    controller.add(1);
    await Future<void>.delayed(Duration.zero);

    expect(notifyCount, 0);
  });
}
