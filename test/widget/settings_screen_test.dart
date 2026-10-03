// T7.8: the settings screen must not claim anything the app cannot back.
// There is no push infrastructure (no FCM, no server-side sender), so there is
// no "receive alerts" switch: alerts live in the Alertes tab, and the screen
// says so plainly. The OS notification permission is never requested.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/push/push_gateway.dart';
import 'package:steriymed_mobile/core/push/push_remote_datasource.dart';
import 'package:steriymed_mobile/core/push/push_service.dart';
import 'package:steriymed_mobile/core/storage/session_store.dart';
import 'package:steriymed_mobile/features/settings/presentation/screens/about_screen.dart';
import 'package:steriymed_mobile/features/settings/presentation/screens/settings_screen.dart';

import '../helpers/pump_app.dart';

class MockSessionStore extends Mock implements SessionStore {}

class _PushRemote extends Mock implements PushRemoteDatasource {}

class _Prefs implements PushPreference {
  bool value = false;
  @override
  bool get enabled => value;
  @override
  Future<void> set(bool v) async => value = v;
}

class _PushGateway implements PushGateway {
  @override
  bool isConfigured = true;
  PushPermission current = PushPermission.notDetermined;
  PushPermission afterRequest = PushPermission.granted;
  @override
  Future<bool> init() async => isConfigured;
  @override
  Future<PushPermission> permission() async => current;
  @override
  Future<PushPermission> requestPermission() async => current = afterRequest;
  @override
  Future<String?> token() async => 'fcm-token-1234567890';
  @override
  Future<void> deleteToken() async {}
  @override
  Stream<String> get onTokenRefresh => const Stream.empty();
  @override
  Stream<PushPayload> get onForeground => const Stream.empty();
  @override
  Stream<PushPayload> get onOpened => const Stream.empty();
  @override
  Future<PushPayload?> launchedBy() async => null;
}

const _channel = MethodChannel('flutter.baseflow.com/permissions/methods');

void main() {
  late MockSessionStore session;
  var permissionChannelCalls = <String>[];

  setUp(() {
    session = MockSessionStore();
    when(() => session.userName).thenReturn('Dr Test');
    when(() => session.userEmail).thenReturn('test@test.com');
    when(() => session.role).thenReturn('owner');
    when(() => session.tenantName).thenReturn('Cabinet Test');
    when(() => session.isOwner).thenReturn(true);
    when(() => session.hasPermission(any())).thenReturn(true);
    if (GetIt.instance.isRegistered<SessionStore>()) {
      GetIt.instance.unregister<SessionStore>();
    }
    GetIt.instance.registerSingleton<SessionStore>(session);

    permissionChannelCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      permissionChannelCalls.add(call.method);
      return null;
    });
  });

  tearDown(() {
    if (GetIt.instance.isRegistered<SessionStore>()) {
      GetIt.instance.unregister<SessionStore>();
    }
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  testWidgets('says alerts are in the app only, and offers no fake switch',
      (tester) async {
    await pumpApp(tester, const SettingsScreen());
    await tester.pumpAndSettle();
    final note = find.byKey(const Key('alerts-in-app-only'));
    await tester.scrollUntilVisible(
      note,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: note, matching: find.textContaining('restent toujours visibles')),
      findsOneWidget,
    );
    // Nothing can be switched on in a build that cannot deliver anything.
    expect(find.byType(Switch), findsNothing);
  });

  group('notifications', () {
    late _PushGateway gateway;
    late _PushRemote remote;
    late _Prefs prefs;

    PushService makeService() => PushService(
          gateway: gateway,
          remote: remote,
          prefs: prefs,
          session: session,
          platform: () => 'android',
        );

    setUp(() {
      gateway = _PushGateway();
      remote = _PushRemote();
      prefs = _Prefs();
      when(() => session.changes).thenAnswer((_) => const Stream<int>.empty());
      when(() => session.hasSession).thenReturn(true);
      when(() => session.generation).thenReturn(1);
      when(() => remote.register(
            token: any(named: 'token'),
            platform: any(named: 'platform'),
            appVersion: any(named: 'appVersion'),
          )).thenAnswer((_) async {});
      when(() => remote.unregister(any())).thenAnswer((_) async {});
    });

    tearDown(() {
      if (GetIt.instance.isRegistered<PushService>()) {
        GetIt.instance.unregister<PushService>();
      }
    });

    Future<PushService> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final service = makeService();
      GetIt.instance.registerSingleton<PushService>(service);
      await service.refresh();
      await pumpApp(tester, const SettingsScreen());
      await tester.pumpAndSettle();
      return service;
    }

    testWidgets('off: a switch, with what the message contains', (tester) async {
      await open(tester);
      final sw = tester.widget<SwitchListTile>(find.byKey(const Key('push-switch')));
      expect(sw.value, isFalse);
      expect(find.textContaining('aucune donnée patient'), findsOneWidget);
    });

    testWidgets('switching it on registers the phone and shows it on',
        (tester) async {
      final service = await open(tester);
      await tester.tap(find.byKey(const Key('push-switch')));
      await tester.pumpAndSettle();

      expect(service.state.availability, PushAvailability.on);
      expect(
        tester.widget<SwitchListTile>(find.byKey(const Key('push-switch'))).value,
        isTrue,
      );
      verify(() => remote.register(
            token: any(named: 'token'),
            platform: 'android',
            appVersion: any(named: 'appVersion'),
          )).called(1);
    });

    testWidgets('switching it off tells the server', (tester) async {
      final service = await open(tester);
      await service.enable();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('push-switch')));
      await tester.pumpAndSettle();

      expect(service.state.availability, PushAvailability.off);
      verify(() => remote.unregister(any())).called(1);
    });

    testWidgets('refused by the phone: says so and offers the phone settings',
        (tester) async {
      gateway.afterRequest = PushPermission.denied;
      await open(tester);
      await tester.tap(find.byKey(const Key('push-switch')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('push-blocked')), findsOneWidget);
      expect(find.byKey(const Key('push-open-settings')), findsOneWidget);
      expect(find.byKey(const Key('push-switch')), findsNothing);
    });

    testWidgets('a failed registration shows the reason and stays off',
        (tester) async {
      when(() => remote.register(
            token: any(named: 'token'),
            platform: any(named: 'platform'),
            appVersion: any(named: 'appVersion'),
          )).thenThrow(Exception('offline'));
      await open(tester);
      await tester.tap(find.byKey(const Key('push-switch')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('push-error')), findsOneWidget);
      expect(
        tester.widget<SwitchListTile>(find.byKey(const Key('push-switch'))).value,
        isFalse,
      );
    });

    testWidgets('a build without Firebase settings offers no switch',
        (tester) async {
      gateway.isConfigured = false;
      await open(tester);
      expect(find.byKey(const Key('push-switch')), findsNothing);
      expect(find.byKey(const Key('alerts-in-app-only')), findsOneWidget);
    });
  });

  testWidgets('never asks the OS for the notification permission',
      (tester) async {
    await pumpApp(tester, const SettingsScreen());
    await tester.pumpAndSettle();

    expect(permissionChannelCalls, isEmpty);
  });

  testWidgets('the owner sees every cabinet and compliance shortcut',
      (tester) async {
    tester.view.physicalSize = const Size(900, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(tester, const SettingsScreen());
    await tester.pumpAndSettle();

    for (final label in [
      'Sites et salles',
      'Appareils',
      'Équipe',
      'Non-conformités',
      "Journal d'audit",
      'Exports de données',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.byKey(const Key('role-description')), findsOneWidget);
  });

  testWidgets('a role without the permissions is offered none of them',
      (tester) async {
    tester.view.physicalSize = const Size(900, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    when(() => session.role).thenReturn('viewer');
    when(() => session.isOwner).thenReturn(false);
    when(() => session.hasPermission(any())).thenReturn(false);
    await pumpApp(tester, const SettingsScreen());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings-hub')), findsNothing);
    expect(find.text("Journal d'audit"), findsNothing);
    expect(find.text('Équipe'), findsNothing);
    expect(find.text('CONSULTATION EN LECTURE SEULE'), findsOneWidget);
  });

  testWidgets('a single permission opens exactly its own row', (tester) async {
    tester.view.physicalSize = const Size(900, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    when(() => session.hasPermission(any())).thenAnswer(
      (i) => i.positionalArguments.first == 'audit.view',
    );
    await pumpApp(tester, const SettingsScreen());
    await tester.pumpAndSettle();

    expect(find.text("Journal d'audit"), findsOneWidget);
    expect(find.text('Sites et salles'), findsNothing);
    expect(find.text('Exports de données'), findsNothing);
  });

  testWidgets('the About text only claims what is true', (tester) async {
    await pumpApp(tester, const AboutScreen());
    await tester.pumpAndSettle();

    expect(find.textContaining('immuable'), findsNothing);
    expect(find.textContaining('HTTPS'), findsOneWidget);
  });
}
