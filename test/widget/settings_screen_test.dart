// The "Recevoir les alertes" switch wires the previously-orphaned
// NotificationPermission helper (lib/core/permissions/notification_permission.dart)
// into real UI for the first time — see docs/SECURITY.md's threat model:
// requested lazily here, never at app startup (lib/bootstrap.dart asks for
// zero permissions). permission_handler has no test double, so this mocks
// its real platform channel directly (verified against the installed
// permission_handler_platform_interface package source, not guessed):
// channel `flutter.baseflow.com/permissions/methods`, methods
// `checkPermissionStatus`/`requestPermissions`, `Permission.notification`
// encodes to `17`, and `PermissionStatus` encodes denied=0/granted=1.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/storage/session_store.dart';
import 'package:steriymed_mobile/features/settings/presentation/screens/settings_screen.dart';

import '../helpers/pump_app.dart';

class MockSessionStore extends Mock implements SessionStore {}

const _channel = MethodChannel('flutter.baseflow.com/permissions/methods');
const _notificationPermissionValue = 17;
const _statusDenied = 0;
const _statusGranted = 1;

void main() {
  late MockSessionStore session;

  setUp(() {
    session = MockSessionStore();
    when(() => session.userName).thenReturn('Dr Test');
    when(() => session.userEmail).thenReturn('test@test.com');
    when(() => session.role).thenReturn('owner');
    when(() => session.tenantName).thenReturn('Cabinet Test');
    when(() => session.isOwner).thenReturn(true);
    if (GetIt.instance.isRegistered<SessionStore>()) {
      GetIt.instance.unregister<SessionStore>();
    }
    GetIt.instance.registerSingleton<SessionStore>(session);
  });

  tearDown(() {
    if (GetIt.instance.isRegistered<SessionStore>()) {
      GetIt.instance.unregister<SessionStore>();
    }
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  void mockPermissionChannel({
    required int checkStatus,
    required int requestStatus,
  }) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      switch (call.method) {
        case 'checkPermissionStatus':
          return checkStatus;
        case 'requestPermissions':
          return {_notificationPermissionValue: requestStatus};
        default:
          return null;
      }
    });
  }

  testWidgets('switch reflects an already-granted permission on load',
      (tester) async {
    mockPermissionChannel(
        checkStatus: _statusGranted, requestStatus: _statusGranted);

    await pumpApp(tester, const SettingsScreen());
    await tester.pumpAndSettle();
    // The Notifications section sits below the fold — a plain ListView
    // lazily mounts only in-viewport (+ cache-extent) children.
    final switchFinder = find.byType(Switch);
    await tester.scrollUntilVisible(
      switchFinder,
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(tester.widget<Switch>(switchFinder).value, isTrue);
  });

  testWidgets(
      'turning the switch on when not yet granted requests the permission',
      (tester) async {
    mockPermissionChannel(
        checkStatus: _statusDenied, requestStatus: _statusGranted);

    await pumpApp(tester, const SettingsScreen());
    await tester.pumpAndSettle();
    final switchFinder = find.byType(Switch);
    await tester.scrollUntilVisible(
      switchFinder,
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(tester.widget<Switch>(switchFinder).value, isFalse);

    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(switchFinder).value, isTrue);
  });

  testWidgets('does not request the permission at all before any interaction',
      (tester) async {
    var requestCalled = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      if (call.method == 'requestPermissions') requestCalled = true;
      if (call.method == 'checkPermissionStatus') return _statusDenied;
      return null;
    });

    await pumpApp(tester, const SettingsScreen());
    await tester.pumpAndSettle();

    expect(requestCalled, isFalse,
        reason: 'only checkPermissionStatus should run on load — '
            'requestPermissions must wait for the user to flip the switch');
  });
}
