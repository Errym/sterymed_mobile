// A notification reaches the app: a tap opens the screen it names (only an
// allowed one), a notification received while the app is open becomes a banner
// with a shortcut, and a signed-out app ignores them all.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steriymed_mobile/core/push/push_gateway.dart';
import 'package:steriymed_mobile/core/push/push_listener.dart';
import 'package:steriymed_mobile/core/push/push_service.dart';

import '../helpers/pump_app.dart';

void main() {
  late StreamController<PushEvent> events;
  late List<String> opened;
  var signedIn = true;

  setUp(() {
    events = StreamController<PushEvent>.broadcast();
    opened = [];
    signedIn = true;
  });

  tearDown(() => events.close());

  Future<void> pumpListener(WidgetTester tester) async {
    await pumpApp(
      tester,
      Scaffold(
        body: PushListener(
          events: events.stream,
          hasSession: () => signedIn,
          onOpen: opened.add,
          child: const Center(child: Text('home')),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a tapped alert notification opens the alerts tab', (tester) async {
    await pumpListener(tester);
    events.add(const PushEvent(
      PushPayload(route: '/app/alerts', body: '1 alerte critique à traiter'),
      opened: true,
    ));
    await tester.pumpAndSettle();
    expect(opened, ['/app/alerts']);
  });

  testWidgets('a notification naming any other screen opens nothing',
      (tester) async {
    await pumpListener(tester);
    events.add(const PushEvent(
      PushPayload(route: '/app/audit', body: 'x'),
      opened: true,
    ));
    events.add(const PushEvent(
      PushPayload(route: 'https://example.com', body: 'x'),
      opened: true,
    ));
    await tester.pumpAndSettle();
    expect(opened, isEmpty);
  });

  testWidgets('received while the app is open: a banner with a shortcut',
      (tester) async {
    await pumpListener(tester);
    events.add(const PushEvent(
      PushPayload(route: '/app/alerts', body: '3 nouvelles alertes'),
      opened: false,
    ));
    // One frame builds the banner, the next ones slide it in.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('3 nouvelles alertes'), findsOneWidget);
    await tester.tap(find.text('Voir'));
    await tester.pumpAndSettle();
    expect(opened, ['/app/alerts']);
  });

  testWidgets('a foreground notification without an allowed route has no shortcut',
      (tester) async {
    await pumpListener(tester);
    events.add(const PushEvent(
      PushPayload(route: '/somewhere', body: 'Hello'),
      opened: false,
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Hello'), findsOneWidget);
    expect(find.text('Voir'), findsNothing);
  });

  testWidgets('signed out: notifications are ignored', (tester) async {
    await pumpListener(tester);
    signedIn = false;
    events.add(const PushEvent(
      PushPayload(route: '/app/alerts', body: 'secret'),
      opened: true,
    ));
    events.add(const PushEvent(
      PushPayload(route: '/app/alerts', body: 'secret'),
      opened: false,
    ));
    await tester.pumpAndSettle();
    expect(opened, isEmpty);
    expect(find.text('secret'), findsNothing);
  });
}
