import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../config/env.dart';

/// Whether this phone may show notifications from SteryMed.
enum PushPermission { granted, denied, notDetermined }

/// What a notification asks the app to open. Only the route is kept, and only
/// if it is one this app agrees to open from a notification (see
/// [PushPayload.safeRoute]): a notification is data from outside the app, so
/// it can never name an arbitrary screen.
class PushPayload {
  final String? route;
  final String body;
  const PushPayload({this.route, this.body = ''});

  static const allowedRoutes = {'/app/alerts'};

  String? get safeRoute => allowedRoutes.contains(route) ? route : null;
}

/// The phone-side push service (Firebase Cloud Messaging), behind an interface
/// so everything above it is testable without a device or a Firebase project.
abstract class PushGateway {
  /// False when this build carries no Firebase settings: push then cannot
  /// work at all, and the app says so instead of pretending.
  bool get isConfigured;

  /// Starts the service. Returns false if it could not start.
  Future<bool> init();

  Future<PushPermission> permission();
  Future<PushPermission> requestPermission();
  Future<String?> token();
  Future<void> deleteToken();

  Stream<String> get onTokenRefresh;

  /// A notification arrived while the app is open.
  Stream<PushPayload> get onForeground;

  /// The user tapped a notification (app was in the background).
  Stream<PushPayload> get onOpened;

  /// The notification that launched the app from a closed state, if any.
  Future<PushPayload?> launchedBy();
}

/// Firebase Cloud Messaging. Configured from build-time `--dart-define`s (the
/// same way as the API address and the Sentry DSN), so no Firebase file or key
/// lives in the repository:
///
///   FIREBASE_API_KEY, FIREBASE_APP_ID, FIREBASE_MESSAGING_SENDER_ID,
///   FIREBASE_PROJECT_ID
class FirebasePushGateway implements PushGateway {
  bool _started = false;

  @override
  bool get isConfigured => Env.pushConfigured;

  @override
  Future<bool> init() async {
    if (!isConfigured) return false;
    if (_started) return true;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: Env.firebaseApiKey,
            appId: Env.firebaseAppId,
            messagingSenderId: Env.firebaseMessagingSenderId,
            projectId: Env.firebaseProjectId,
          ),
        );
      }
      _started = true;
    } catch (_) {
      _started = false;
    }
    return _started;
  }

  static PushPermission _map(AuthorizationStatus s) => switch (s) {
        AuthorizationStatus.authorized ||
        AuthorizationStatus.provisional =>
          PushPermission.granted,
        AuthorizationStatus.denied ||
        AuthorizationStatus.deniedPermanently =>
          PushPermission.denied,
        AuthorizationStatus.notDetermined => PushPermission.notDetermined,
      };

  @override
  Future<PushPermission> permission() async {
    if (!await init()) return PushPermission.denied;
    final s = await FirebaseMessaging.instance.getNotificationSettings();
    return _map(s.authorizationStatus);
  }

  @override
  Future<PushPermission> requestPermission() async {
    if (!await init()) return PushPermission.denied;
    final s = await FirebaseMessaging.instance.requestPermission();
    return _map(s.authorizationStatus);
  }

  @override
  Future<String?> token() async {
    if (!await init()) return null;
    return FirebaseMessaging.instance.getToken();
  }

  @override
  Future<void> deleteToken() async {
    if (!await init()) return;
    await FirebaseMessaging.instance.deleteToken();
  }

  static PushPayload _payload(RemoteMessage m) => PushPayload(
        route: m.data['route']?.toString(),
        body: m.notification?.body ?? '',
      );

  // Streams are created lazily and only once Firebase is up, so a build
  // without Firebase settings never touches the plugin.
  @override
  Stream<String> get onTokenRefresh async* {
    if (await init()) yield* FirebaseMessaging.instance.onTokenRefresh;
  }

  @override
  Stream<PushPayload> get onForeground async* {
    if (await init()) yield* FirebaseMessaging.onMessage.map(_payload);
  }

  @override
  Stream<PushPayload> get onOpened async* {
    if (await init()) yield* FirebaseMessaging.onMessageOpenedApp.map(_payload);
  }

  @override
  Future<PushPayload?> launchedBy() async {
    if (!await init()) return null;
    final m = await FirebaseMessaging.instance.getInitialMessage();
    return m == null ? null : _payload(m);
  }
}
