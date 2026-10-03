// Shared helpers for the Chrome journeys (`flutter drive -d chrome`). They run
// the real app against the dev backend, with the practice written by
// scripts/seed_web_journeys.py to build/web-journeys/defines.json. No mock.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:steriymed_mobile/app.dart';
import 'package:steriymed_mobile/bootstrap.dart';
import 'package:steriymed_mobile/core/storage/session_store.dart';
import 'package:steriymed_mobile/di/di.dart';

abstract final class WebEnv {
  static const slug = String.fromEnvironment('WEB_TENANT_SLUG');
  static const password = String.fromEnvironment('WEB_PASSWORD');
  static const emailOwner = String.fromEnvironment('WEB_EMAIL_OWNER');
  static const emailAdmin = String.fromEnvironment('WEB_EMAIL_ADMIN');
  static const emailStockManager = String.fromEnvironment(
    'WEB_EMAIL_STOCK_MANAGER',
  );
  static const emailReleaser = String.fromEnvironment('WEB_EMAIL_RELEASER');
  static const emailPractitioner = String.fromEnvironment(
    'WEB_EMAIL_PRACTITIONER',
  );
  static const emailViewer = String.fromEnvironment('WEB_EMAIL_VIEWER');
  static const ownerId = String.fromEnvironment('WEB_OWNER_ID');
  static const deviceName = String.fromEnvironment('WEB_DEVICE_NAME');
  static const glovesName = String.fromEnvironment('WEB_GLOVES_NAME');
  static const glovesBarcode = String.fromEnvironment('WEB_GLOVES_BARCODE');
  static const glovesLot = String.fromEnvironment('WEB_GLOVES_LOT');
  static const masksName = String.fromEnvironment('WEB_MASKS_NAME');
  static const poId = String.fromEnvironment('WEB_PO_ID');
  static const labelFresh = String.fromEnvironment('WEB_LABEL_FRESH');
  static const labelSpare = String.fromEnvironment('WEB_LABEL_SPARE');
  static const patientId = String.fromEnvironment('WEB_PATIENT_ID');
  static const labName = String.fromEnvironment('WEB_LAB_NAME');

  static const roles = <String, String>{
    'owner': emailOwner,
    'admin': emailAdmin,
    'stock_manager': emailStockManager,
    'releaser': emailReleaser,
    'practitioner': emailPractitioner,
    'viewer': emailViewer,
  };

  static void requireSeed() {
    if (slug.isEmpty || password.isEmpty) {
      throw StateError(
        'Seed first: python scripts/seed_web_journeys.py, then pass '
        '--dart-define-from-file=build/web-journeys/defines.json',
      );
    }
  }
}

/// Pumps frames for [seconds] of real time. `pumpAndSettle` never returns on a
/// screen with a running spinner or scan-line animation, so waits are bounded.
Future<void> settle(WidgetTester tester, [double seconds = 2]) async {
  final end = DateTime.now().add(Duration(milliseconds: (seconds * 1000).round()));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

/// Waits (bounded) until [finder] matches, pumping as it goes.
Future<bool> waitFor(
  WidgetTester tester,
  Finder finder, {
  double seconds = 10,
}) async {
  final end = DateTime.now().add(Duration(milliseconds: (seconds * 1000).round()));
  while (DateTime.now().isBefore(end)) {
    if (finder.evaluate().isNotEmpty) return true;
    await tester.pump(const Duration(milliseconds: 100));
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  return finder.evaluate().isNotEmpty;
}

bool _booted = false;

Future<void> launchApp(WidgetTester tester) async {
  WebEnv.requireSeed();
  if (!_booted) {
    await bootstrap(() => const SteryMedApp());
    _booted = true;
  }
  await settle(tester, 2);
}

Future<void> signIn(WidgetTester tester, String role) async {
  final email = WebEnv.roles[role]!;
  expect(await waitFor(tester, find.text('Se connecter')), isTrue,
      reason: 'login screen should be showing before signing in as $role');
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), WebEnv.slug);
  await tester.enterText(fields.at(1), email);
  await tester.enterText(fields.at(2), WebEnv.password);
  await tester.pump();
  await tester.tap(find.text('Se connecter'));
  expect(await waitFor(tester, find.text('Accueil'), seconds: 60), isTrue,
      reason: 'signing in as $role should reach the shell');
  await settle(tester, 2);
}

Future<void> signOut(WidgetTester tester) async {
  goTo(tester, '/app/settings');
  await settle(tester, 2);
  final out = find.text('Se déconnecter');
  await tester.scrollUntilVisible(out, 200, scrollable: find.byType(Scrollable).first);
  await tester.tap(out);
  await settle(tester, 1);
  // Some builds ask for confirmation.
  final confirm = find.descendant(
    of: find.byType(AlertDialog),
    matching: find.textContaining('connecter'),
  );
  if (confirm.evaluate().isNotEmpty) {
    await tester.tap(confirm.last);
  }
  expect(await waitFor(tester, find.text('Se connecter'), seconds: 15), isTrue,
      reason: 'sign-out should return to the login screen');
}

GoRouter _router(WidgetTester tester) {
  final ctx = tester.element(find.byType(Scaffold).first);
  return GoRouter.of(ctx);
}

/// Removes any snackbar still floating over the bottom of the screen. A real
/// person waits for it or swipes it away; a test is faster than the 4 s it
/// stays up and would otherwise tap the snackbar instead of the button below.
void clearSnackbars(WidgetTester tester) {
  final scaffolds = find.byType(Scaffold);
  if (scaffolds.evaluate().isEmpty) return;
  ScaffoldMessenger.maybeOf(tester.element(scaffolds.first))?.clearSnackBars();
}

/// Jumps straight to [path], like a deep link. Used by the access sweep.
void goTo(WidgetTester tester, String path) {
  clearSnackbars(tester);
  _router(tester).go(path);
}

/// Opens [path] the way a person gets there: a screen below a tab is pushed
/// on top of that tab, so it has a back stack to pop (the stock screens pop
/// themselves after saving). A bare `go()` to such a screen has nothing to
/// pop and the save would be reported as a failure.
void openScreen(WidgetTester tester, String path) {
  clearSnackbars(tester);
  final router = _router(tester);
  final parts = path.split('/'); // ['', 'app', 'stock', 'issue']
  if (parts.length <= 3) {
    router.go(path);
    return;
  }
  router.go(parts.take(3).join('/'));
  router.push(path);
}

/// The path the router is on right now (after any redirect).
String currentPath(WidgetTester tester) {
  final cfg = _router(tester).routerDelegate.currentConfiguration;
  return cfg.uri.path;
}

bool can(String permission) => getIt<SessionStore>().hasPermission(permission);

/// Fails the journey if a frame threw (overflow, null error, bad state...).
void expectNoFrameError(WidgetTester tester, String where) {
  final e = tester.takeException();
  expect(e, isNull, reason: 'exception while on $where: $e');
}

/// Server read-back: what the backend itself holds, independent of the UI.
class ServerApi {
  static String? _token;

  static Future<String> _login() async {
    if (_token != null) return _token!;
    final res = await http.post(
      Uri.parse('${const String.fromEnvironment('API_BASE_URL')}/v1/auth/login'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Idempotency-Key': 'login-${DateTime.now().microsecondsSinceEpoch}-web',
      },
      body: jsonEncode({
        'tenant_slug': WebEnv.slug,
        'email': WebEnv.emailOwner,
        'password': WebEnv.password,
      }),
    );
    _token = (jsonDecode(res.body) as Map)['token'] as String;
    return _token!;
  }

  static Future<dynamic> get(String path) async {
    final token = await _login();
    final res = await http.get(
      Uri.parse('${const String.fromEnvironment('API_BASE_URL')}$path'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
    return jsonDecode(res.body);
  }

  /// A write straight to the server (set-up that is not the step under test).
  static Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final token = await _login();
    final key = '${DateTime.now().microsecondsSinceEpoch}-${path.hashCode.abs()}-web';
    final res = await http.post(
      Uri.parse('${const String.fromEnvironment('API_BASE_URL')}$path'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Idempotency-Key': key,
      },
      body: jsonEncode(body),
    );
    if (res.statusCode >= 300) {
      throw StateError('POST $path -> ${res.statusCode}: ${res.body}');
    }
    return jsonDecode(res.body);
  }

  /// Quantity of [lot] at the place called [place] (0 when absent).
  static Future<int> stockOf(String lot, String place) async {
    final body = await get('/v1/stock-levels?limit=200') as Map;
    for (final r in (body['data'] as List).cast<Map>()) {
      if (r['batch_number'] == lot && r['location_name'] == place) {
        return (r['quantity'] as num).toInt();
      }
    }
    return 0;
  }
}
