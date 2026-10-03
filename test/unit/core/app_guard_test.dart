// Phase 7 / T7.5 + T7.6: minimum-version gate and the inactivity lock.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steriymed_mobile/core/security/app_guard.dart';
import 'package:steriymed_mobile/core/security/inactivity_lock.dart';
import 'package:steriymed_mobile/core/version/version_gate.dart';

class _FakeAuth implements DeviceAuthenticator {
  bool supported = true;
  bool succeeds = true;
  int asked = 0;
  @override
  Future<bool> isSupported() async => supported;
  @override
  Future<bool> authenticate(String reason) async {
    asked++;
    return succeeds;
  }
}

class _Handler extends ResponseInterceptorHandler {}

class _ErrHandler extends ErrorInterceptorHandler {
  Future<void> get settled => future.then((_) {}, onError: (_) {});
}

void main() {
  group('AppVersion', () {
    test('compares segment by segment, not as text', () {
      expect(AppVersion.isOlder('0.2.0', '0.10.0'), isTrue);
      expect(AppVersion.isOlder('1.0.0', '0.9.9'), isFalse);
      expect(AppVersion.isOlder('1.4.0', '1.4.0'), isFalse);
      expect(AppVersion.isOlder('1.4', '1.4.1'), isTrue);
    });

    test('the build number after + never counts', () {
      expect(AppVersion.isOlder('1.4.0+3', '1.4.0'), isFalse);
      expect(AppVersion.isOlder('1.4.0+99', '1.4.1'), isTrue);
    });

    test('a malformed version never locks the app', () {
      expect(AppVersion.isOlder('1.4.0', 'banana'), isFalse);
      expect(AppVersion.isOlder('1.4.0', ''), isFalse);
      expect(AppVersion.isOlder('weird', '2.0.0'), isFalse);
    });
  });

  group('VersionGate', () {
    test('never blocks until the server names a minimum', () {
      final gate = VersionGate(currentVersion: () => '0.2.0');
      expect(gate.blocked, isFalse);
    });

    test('blocks when the server minimum is newer, unblocks when lowered', () {
      final gate = VersionGate(currentVersion: () => '0.2.0');
      var notified = 0;
      gate.addListener(() => notified++);
      gate.observe('0.3.0');
      expect(gate.blocked, isTrue);
      gate.observe('0.2.0');
      expect(gate.blocked, isFalse);
      expect(notified, 2);
    });

    test('an unreadable header is ignored', () {
      final gate = VersionGate(currentVersion: () => '0.2.0');
      gate.observe('0.3.0');
      gate.observe('garbage');
      expect(gate.blocked, isTrue);
    });

    test('a 426 without a version still blocks', () {
      final gate = VersionGate(currentVersion: () => '0.2.0');
      gate.markUpdateRequired(null);
      expect(gate.blocked, isTrue);
    });
  });

  group('VersionGateInterceptor', () {
    test('tells the server which build is calling', () {
      final gate = VersionGate(currentVersion: () => '0.2.0');
      final options = RequestOptions(path: '/x');
      VersionGateInterceptor(gate).onRequest(options, RequestInterceptorHandler());
      expect(options.headers['X-App-Version'], '0.2.0');
    });

    test('reads the minimum from any response', () {
      final gate = VersionGate(currentVersion: () => '0.2.0');
      final res = Response(
        requestOptions: RequestOptions(path: '/x'),
        headers: Headers.fromMap({
          'x-min-app-version': ['0.5.0'],
        }),
      );
      VersionGateInterceptor(gate).onResponse(res, _Handler());
      expect(gate.blocked, isTrue);
      expect(gate.requiredVersion, '0.5.0');
    });

    test('a 426 blocks even from an error response', () async {
      final gate = VersionGate(currentVersion: () => '0.2.0');
      final err = DioException(
        requestOptions: RequestOptions(path: '/x'),
        response: Response(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: 426,
          headers: Headers.fromMap({
            'x-min-app-version': ['1.0.0'],
          }),
        ),
      );
      final handler = _ErrHandler();
      final done = handler.settled;
      VersionGateInterceptor(gate).onError(err, handler);
      await done;
      expect(gate.blocked, isTrue);
      expect(gate.requiredVersion, '1.0.0');
    });
  });

  group('InactivityLock', () {
    late _FakeAuth auth;
    late DateTime clock;
    late bool signedIn;
    late int signedOut;
    late InactivityLock lock;

    setUp(() {
      auth = _FakeAuth();
      clock = DateTime(2026, 10, 2, 9);
      signedIn = true;
      signedOut = 0;
      lock = InactivityLock(
        timeout: const Duration(minutes: 2),
        isSignedIn: () => signedIn,
        authenticator: auth,
        onNoDeviceLock: () => signedOut++,
        now: () => clock,
      );
    });

    Future<void> away(Duration d) async {
      lock.didChangeAppLifecycleState(AppLifecycleState.paused);
      clock = clock.add(d);
      lock.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
    }

    test('a quick app switch never asks', () async {
      await away(const Duration(seconds: 30));
      expect(lock.locked, isFalse);
    });

    test('coming back after the timeout locks', () async {
      await away(const Duration(minutes: 3));
      expect(lock.locked, isTrue);
    });

    test('merely inactive (permission dialog, shade) is not leaving the app',
        () async {
      lock.didChangeAppLifecycleState(AppLifecycleState.inactive);
      clock = clock.add(const Duration(minutes: 10));
      lock.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      expect(lock.locked, isFalse);
    });

    test('nobody signed in means nothing to lock', () async {
      signedIn = false;
      await away(const Duration(minutes: 10));
      expect(lock.locked, isFalse);
    });

    test('a failed unlock keeps it locked; a successful one opens it',
        () async {
      await away(const Duration(minutes: 3));
      auth.succeeds = false;
      expect(await lock.unlock(), isFalse);
      expect(lock.locked, isTrue);
      auth.succeeds = true;
      expect(await lock.unlock(), isTrue);
      expect(lock.locked, isFalse);
    });

    test('a device with no screen lock signs the user out instead', () async {
      auth.supported = false;
      await away(const Duration(minutes: 3));
      expect(lock.locked, isFalse);
      expect(signedOut, 1);
    });

    test('a second return while locked does not stack prompts', () async {
      await away(const Duration(minutes: 3));
      await away(const Duration(minutes: 3));
      expect(lock.locked, isTrue);
      expect(auth.asked, 0);
    });
  });

  group('AppGuard', () {
    late _FakeAuth auth;
    late VersionGate gate;
    late InactivityLock lock;
    late int signedOut;

    setUp(() {
      auth = _FakeAuth();
      gate = VersionGate(currentVersion: () => '0.2.0');
      signedOut = 0;
      lock = InactivityLock(
        timeout: const Duration(minutes: 2),
        isSignedIn: () => true,
        authenticator: auth,
        onNoDeviceLock: () {},
      );
    });

    Widget app() => MaterialApp(
          home: AppGuard(
            gate: gate,
            lock: lock,
            onSignOut: () => signedOut++,
            child: const Scaffold(body: Text('contenu')),
          ),
        );

    testWidgets('shows the app normally', (tester) async {
      await tester.pumpWidget(app());
      expect(find.text('contenu'), findsOneWidget);
      expect(find.byKey(const Key('update-required')), findsNothing);
      expect(find.byKey(const Key('lock-screen')), findsNothing);
    });

    testWidgets('a too-old build gets a blocking screen with nothing behind it',
        (tester) async {
      await tester.pumpWidget(app());
      gate.observe('0.9.0');
      await tester.pump();
      expect(find.byKey(const Key('update-required')), findsOneWidget);
      expect(find.text('Mise à jour requise'), findsOneWidget);
      expect(find.textContaining('0.9.0'), findsOneWidget);
      expect(find.text('contenu'), findsNothing);
    });

    testWidgets('a 426 without a version says it without inventing one',
        (tester) async {
      await tester.pumpWidget(app());
      gate.markUpdateRequired(null);
      await tester.pump();
      expect(find.byKey(const Key('update-required')), findsOneWidget);
      expect(find.textContaining('999999'), findsNothing);
    });

    testWidgets('the lock covers the app and unlocking uncovers it',
        (tester) async {
      auth.succeeds = false;
      await tester.pumpWidget(app());
      lock.didChangeAppLifecycleState(AppLifecycleState.paused);
      // Simulate the timeout having elapsed.
      final late = InactivityLock(
        timeout: Duration.zero,
        isSignedIn: () => true,
        authenticator: auth,
        onNoDeviceLock: () {},
      );
      gate.reset();
      await tester.pumpWidget(MaterialApp(
        home: AppGuard(
          gate: gate,
          lock: late,
          onSignOut: () => signedOut++,
          child: const Scaffold(body: Text('contenu')),
        ),
      ));
      late.didChangeAppLifecycleState(AppLifecycleState.paused);
      late.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('lock-screen')), findsOneWidget);
      expect(find.text('Déverrouillage non confirmé. Réessayez.'),
          findsOneWidget);

      auth.succeeds = true;
      await tester.tap(find.byKey(const Key('lock-unlock')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('lock-screen')), findsNothing);
      // The app underneath was never torn down.
      expect(find.text('contenu'), findsOneWidget);
    });

    testWidgets('sign out from the lock screen unlocks and signs out',
        (tester) async {
      auth.succeeds = false;
      final late = InactivityLock(
        timeout: Duration.zero,
        isSignedIn: () => true,
        authenticator: auth,
        onNoDeviceLock: () {},
      );
      await tester.pumpWidget(MaterialApp(
        home: AppGuard(
          gate: gate,
          lock: late,
          onSignOut: () => signedOut++,
          child: const Scaffold(body: Text('contenu')),
        ),
      ));
      late.didChangeAppLifecycleState(AppLifecycleState.paused);
      late.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(const Key('lock-sign-out')));
      await tester.pump();
      expect(signedOut, 1);
      expect(find.byKey(const Key('lock-screen')), findsNothing);
    });
  });
}
