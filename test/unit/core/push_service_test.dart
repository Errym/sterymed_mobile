// Push notifications, below the UI: who is registered when, what happens when
// the phone refuses, when the server is unreachable, and that a notification
// can never open a screen the app did not agree to.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/push/push_gateway.dart';
import 'package:steriymed_mobile/core/push/push_remote_datasource.dart';
import 'package:steriymed_mobile/core/push/push_service.dart';
import 'package:steriymed_mobile/core/storage/session_store.dart';

class _MockRemote extends Mock implements PushRemoteDatasource {}

class _MockSession extends Mock implements SessionStore {}

class _MemPrefs implements PushPreference {
  bool value = false;
  @override
  bool get enabled => value;
  @override
  Future<void> set(bool v) async => value = v;
}

class _FakeGateway implements PushGateway {
  @override
  bool isConfigured = true;
  PushPermission current = PushPermission.notDetermined;
  PushPermission afterRequest = PushPermission.granted;
  String? tokenValue = 'fcm-token-1234567890';
  int requestCalls = 0;
  int deleteCalls = 0;
  final refresh = StreamController<String>.broadcast();
  final foreground = StreamController<PushPayload>.broadcast();
  final opened = StreamController<PushPayload>.broadcast();
  PushPayload? launch;

  @override
  Future<bool> init() async => isConfigured;
  @override
  Future<PushPermission> permission() async => current;
  @override
  Future<PushPermission> requestPermission() async {
    requestCalls++;
    current = afterRequest;
    return current;
  }

  @override
  Future<String?> token() async => tokenValue;
  @override
  Future<void> deleteToken() async => deleteCalls++;
  @override
  Stream<String> get onTokenRefresh => refresh.stream;
  @override
  Stream<PushPayload> get onForeground => foreground.stream;
  @override
  Stream<PushPayload> get onOpened => opened.stream;
  @override
  Future<PushPayload?> launchedBy() async => launch;
}

void main() {
  late _FakeGateway gateway;
  late _MockRemote remote;
  late _MemPrefs prefs;
  late _MockSession session;
  late StreamController<int> sessionChanges;
  var generation = 1;
  var signedIn = true;

  PushService build() => PushService(
        gateway: gateway,
        remote: remote,
        prefs: prefs,
        session: session,
        platform: () => 'android',
      );

  setUp(() {
    gateway = _FakeGateway();
    remote = _MockRemote();
    prefs = _MemPrefs();
    session = _MockSession();
    sessionChanges = StreamController<int>.broadcast(sync: true);
    generation = 1;
    signedIn = true;
    when(() => session.changes).thenAnswer((_) => sessionChanges.stream);
    when(() => session.hasSession).thenAnswer((_) => signedIn);
    when(() => session.generation).thenAnswer((_) => generation);
    when(() => remote.register(
          token: any(named: 'token'),
          platform: any(named: 'platform'),
          appVersion: any(named: 'appVersion'),
        )).thenAnswer((_) async {});
    when(() => remote.unregister(any())).thenAnswer((_) async {});
  });

  tearDown(() => sessionChanges.close());

  group('what the person sees', () {
    test('a build without Firebase settings says push is not configured',
        () async {
      gateway.isConfigured = false;
      final s = build();
      await s.refresh();
      expect(s.state.availability, PushAvailability.notConfigured);
      verifyNever(() => remote.register(
            token: any(named: 'token'),
            platform: any(named: 'platform'),
            appVersion: any(named: 'appVersion'),
          ));
      await s.enable();
      expect(gateway.requestCalls, 0);
    });

    test('off until the person turns it on, and nothing is registered',
        () async {
      final s = build();
      await s.refresh();
      expect(s.state.availability, PushAvailability.off);
      verifyNever(() => remote.register(
            token: any(named: 'token'),
            platform: any(named: 'platform'),
            appVersion: any(named: 'appVersion'),
          ));
    });
  });

  group('turning it on', () {
    test('asks the phone, registers the token, remembers the choice', () async {
      final s = build();
      await s.enable();
      expect(gateway.requestCalls, 1);
      verify(() => remote.register(
            token: 'fcm-token-1234567890',
            platform: 'android',
            appVersion: any(named: 'appVersion'),
          )).called(1);
      expect(prefs.enabled, isTrue);
      expect(s.state.availability, PushAvailability.on);
      expect(s.state.error, isNull);
    });

    test('does not ask again when the phone already allows it', () async {
      gateway.current = PushPermission.granted;
      final s = build();
      await s.enable();
      expect(gateway.requestCalls, 0);
      expect(s.state.availability, PushAvailability.on);
    });

    test('a refusal by the phone is explained and nothing is registered',
        () async {
      gateway.afterRequest = PushPermission.denied;
      final s = build();
      await s.enable();
      expect(s.state.availability, PushAvailability.blocked);
      expect(prefs.enabled, isFalse);
      verifyNever(() => remote.register(
            token: any(named: 'token'),
            platform: any(named: 'platform'),
            appVersion: any(named: 'appVersion'),
          ));
    });

    test('if the server cannot be reached it stays off and says why', () async {
      when(() => remote.register(
            token: any(named: 'token'),
            platform: any(named: 'platform'),
            appVersion: any(named: 'appVersion'),
          )).thenThrow(Exception('offline'));
      final s = build();
      await s.enable();
      expect(s.state.availability, PushAvailability.off);
      expect(s.state.error, isNotNull);
      expect(prefs.enabled, isFalse,
          reason: 'a switch must not look on when nothing is registered');
    });

    test('a phone with no token yet stays off with a clear message', () async {
      gateway.tokenValue = null;
      final s = build();
      await s.enable();
      expect(s.state.availability, PushAvailability.off);
      expect(s.state.error, contains('identifiant'));
      expect(prefs.enabled, isFalse);
    });
  });

  group('turning it off', () {
    test('tells the server and drops the phone token', () async {
      prefs.value = true;
      gateway.current = PushPermission.granted;
      final s = build();
      await s.refresh();
      await s.disable();
      verify(() => remote.unregister('fcm-token-1234567890')).called(1);
      expect(gateway.deleteCalls, 1);
      expect(prefs.enabled, isFalse);
      expect(s.state.availability, PushAvailability.off);
    });

    test('works offline: the token is still dropped and the choice kept',
        () async {
      prefs.value = true;
      gateway.current = PushPermission.granted;
      when(() => remote.unregister(any())).thenThrow(Exception('offline'));
      final s = build();
      await s.refresh();
      await s.disable();
      expect(gateway.deleteCalls, 1);
      expect(prefs.enabled, isFalse);
      expect(s.state.availability, PushAvailability.off);
    });
  });

  group('on every start', () {
    test('a remembered "on" re-registers the phone quietly', () async {
      prefs.value = true;
      gateway.current = PushPermission.granted;
      final s = build();
      await s.refresh();
      expect(s.state.availability, PushAvailability.on);
      verify(() => remote.register(
            token: any(named: 'token'),
            platform: any(named: 'platform'),
            appVersion: any(named: 'appVersion'),
          )).called(1);
    });

    test('permission taken away in the phone settings shows as blocked',
        () async {
      prefs.value = true;
      gateway.current = PushPermission.denied;
      final s = build();
      await s.refresh();
      expect(s.state.availability, PushAvailability.blocked);
    });

    test('a server failure at start does not turn the choice off', () async {
      prefs.value = true;
      gateway.current = PushPermission.granted;
      when(() => remote.register(
            token: any(named: 'token'),
            platform: any(named: 'platform'),
            appVersion: any(named: 'appVersion'),
          )).thenThrow(Exception('offline'));
      final s = build();
      await s.refresh();
      expect(s.state.availability, PushAvailability.on);
      expect(prefs.enabled, isTrue);
    });

    test('a rotated phone token is sent to the server', () async {
      prefs.value = true;
      gateway.current = PushPermission.granted;
      final s = build();
      await s.refresh();
      gateway.refresh.add('rotated-token-0987654321');
      await Future<void>.delayed(Duration.zero);
      verify(() => remote.register(
            token: 'rotated-token-0987654321',
            platform: 'android',
            appVersion: any(named: 'appVersion'),
          )).called(1);
    });
  });

  group('following the session', () {
    test('a new login reads that person\'s choice, a sign-out resets', () async {
      final s = build()..attach();
      await Future<void>.delayed(Duration.zero);
      expect(s.state.availability, PushAvailability.off);

      prefs.value = true;
      gateway.current = PushPermission.granted;
      generation = 2;
      sessionChanges.add(2);
      await Future<void>.delayed(Duration.zero);
      expect(s.state.availability, PushAvailability.on);

      signedIn = false;
      sessionChanges.add(3);
      await Future<void>.delayed(Duration.zero);
      expect(s.state.availability, PushAvailability.off);
      await s.close();
    });

    test('routine session refreshes do not re-register the phone', () async {
      prefs.value = true;
      gateway.current = PushPermission.granted;
      final s = build()..attach();
      await Future<void>.delayed(Duration.zero);
      sessionChanges.add(1);
      sessionChanges.add(1);
      await Future<void>.delayed(Duration.zero);
      verify(() => remote.register(
            token: any(named: 'token'),
            platform: any(named: 'platform'),
            appVersion: any(named: 'appVersion'),
          )).called(1);
      await s.close();
    });
  });

  group('notifications reaching the app', () {
    test('foreground, tapped and launch notifications are all forwarded',
        () async {
      prefs.value = true;
      gateway.current = PushPermission.granted;
      gateway.launch = const PushPayload(route: '/app/alerts', body: 'launch');
      final s = build();
      final seen = <PushEvent>[];
      s.events.listen(seen.add);
      await s.refresh();
      gateway.foreground.add(const PushPayload(body: 'fg'));
      gateway.opened.add(const PushPayload(route: '/app/alerts', body: 'tap'));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(seen.map((e) => (e.payload.body, e.opened)).toSet(), {
        ('launch', true),
        ('fg', false),
        ('tap', true),
      });
    });

    test('nothing is listened to while notifications are off', () async {
      final s = build();
      final seen = <PushEvent>[];
      s.events.listen(seen.add);
      await s.refresh();
      gateway.foreground.add(const PushPayload(body: 'x'));
      await Future<void>.delayed(Duration.zero);
      expect(seen, isEmpty);
    });

    test('a notification can only open a route the app allows', () {
      expect(const PushPayload(route: '/app/alerts').safeRoute, '/app/alerts');
      expect(const PushPayload(route: '/app/settings').safeRoute, isNull);
      expect(const PushPayload(route: 'https://evil.example').safeRoute, isNull);
      expect(const PushPayload(route: '/app/alerts/../../x').safeRoute, isNull);
      expect(const PushPayload().safeRoute, isNull);
    });
  });
}
