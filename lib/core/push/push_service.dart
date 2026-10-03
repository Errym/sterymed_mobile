import 'dart:async';
import 'dart:io' show Platform;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../config/build_info.dart';
import '../utils/error_message.dart';
import '../storage/key_value_store.dart';
import '../storage/session_store.dart';
import 'push_gateway.dart';
import 'push_remote_datasource.dart';

enum PushAvailability {
  /// This build has no Firebase settings: push cannot work.
  notConfigured,

  /// The person switched notifications on, but the phone refuses them.
  blocked,

  /// Notifications are off for this person on this phone.
  off,

  /// This phone is registered and will be notified.
  on,
}

class PushState extends Equatable {
  final PushAvailability availability;
  final bool busy;

  /// The reason the last switch failed, in words for the user.
  final String? error;

  const PushState({
    this.availability = PushAvailability.off,
    this.busy = false,
    this.error,
  });

  PushState copyWith({
    PushAvailability? availability,
    bool? busy,
    String? error,
    bool clearError = false,
  }) =>
      PushState(
        availability: availability ?? this.availability,
        busy: busy ?? this.busy,
        error: clearError ? null : (error ?? this.error),
      );

  @override
  List<Object?> get props => [availability, busy, error];
}

/// A notification, as the screens need it: open the screen it names (user
/// tapped it) or just tell the person (it arrived while the app is open).
class PushEvent {
  final PushPayload payload;
  final bool opened;
  const PushEvent(this.payload, {required this.opened});
}

/// Whether THIS person turned notifications on, on this phone. Stored per
/// account (KeyValueStore is owner-scoped), so a colleague signing in on the
/// same phone starts with their own choice, not the previous person's.
class PushPreference {
  static const _key = 'push.enabled';
  final KeyValueStore _kv;
  PushPreference(this._kv);

  bool get enabled => _kv.get(_key) == true;
  Future<void> set(bool value) => _kv.set(_key, value);
}

/// Registers this phone for alert notifications, only when the signed-in
/// person asked for them and the phone allows them.
///
/// Signing out needs no call here: the server removes a phone's registration
/// together with the login it was made under.
class PushService extends Cubit<PushState> {
  final PushGateway gateway;
  final PushRemoteDatasource remote;
  final PushPreference prefs;
  final SessionStore session;
  final String Function() _platform;

  final _events = StreamController<PushEvent>.broadcast();
  StreamSubscription<int>? _sessionSub;
  int? _lastGeneration;
  final List<StreamSubscription<dynamic>> _liveSubs = [];

  PushService({
    required this.gateway,
    required this.remote,
    required this.prefs,
    required this.session,
    String Function()? platform,
  })  : _platform = platform ?? (() => Platform.isIOS ? 'ios' : 'android'),
        super(const PushState());

  Stream<PushEvent> get events => _events.stream;

  /// Follows the session: a new sign-in re-reads that person's choice, a
  /// sign-out stops listening.
  void attach() {
    _sessionSub ??= session.changes.listen((_) {
      if (!session.hasSession) {
        _lastGeneration = null;
        _stopListening();
        emit(const PushState());
      } else if (session.generation != _lastGeneration) {
        // A new login only. Routine permission refreshes also fire this
        // stream and must not re-register the phone every time.
        _lastGeneration = session.generation;
        unawaited(refresh());
      }
    });
    if (session.hasSession) {
      _lastGeneration = session.generation;
      unawaited(refresh());
    }
  }

  /// Reads the real situation (build, phone permission, the person's choice).
  Future<void> refresh() async {
    if (!gateway.isConfigured) {
      emit(const PushState(availability: PushAvailability.notConfigured));
      return;
    }
    final permission = await gateway.permission();
    if (!prefs.enabled) {
      emit(const PushState(availability: PushAvailability.off));
      return;
    }
    if (permission != PushPermission.granted) {
      emit(const PushState(availability: PushAvailability.blocked));
      return;
    }
    emit(const PushState(availability: PushAvailability.on));
    await _registerAndListen(quiet: true);
  }

  /// The person switches notifications on. The phone's permission is asked
  /// here, at the moment it makes sense, never at launch.
  Future<void> enable() async {
    if (state.busy || !gateway.isConfigured) return;
    emit(state.copyWith(busy: true, clearError: true));
    try {
      var permission = await gateway.permission();
      if (permission != PushPermission.granted) {
        permission = await gateway.requestPermission();
      }
      if (permission != PushPermission.granted) {
        emit(const PushState(availability: PushAvailability.blocked));
        return;
      }
      final ok = await _registerAndListen(quiet: false);
      if (!ok) return;
      await prefs.set(true);
      emit(const PushState(availability: PushAvailability.on));
    } catch (e) {
      emit(PushState(
        availability: PushAvailability.off,
        error: ErrorMessage.from(e),
      ));
    }
  }

  /// The person switches notifications off. The server is told, and the
  /// phone's token is dropped so a missed server call cannot keep notifying.
  Future<void> disable() async {
    if (state.busy) return;
    emit(state.copyWith(busy: true, clearError: true));
    _stopListening();
    try {
      final token = await gateway.token();
      if (token != null) {
        try {
          await remote.unregister(token);
        } catch (_) {
          // Offline: dropping the token below still ends delivery; the server
          // forgets the dead token the next time it tries it.
        }
      }
      await gateway.deleteToken();
    } catch (_) {}
    await prefs.set(false);
    emit(const PushState(availability: PushAvailability.off));
  }

  Future<bool> _registerAndListen({required bool quiet}) async {
    try {
      final token = await gateway.token();
      if (token == null) {
        if (!quiet) {
          emit(const PushState(
            availability: PushAvailability.off,
            error: 'Ce téléphone n\'a pas pu obtenir son identifiant de '
                'notification. Réessayez avec une connexion.',
          ));
        }
        return false;
      }
      await remote.register(
        token: token,
        platform: _platform(),
        appVersion: BuildInfo.fullVersion,
      );
      _listen();
      return true;
    } catch (e) {
      if (!quiet) {
        emit(PushState(
          availability: PushAvailability.off,
          error: ErrorMessage.from(e),
        ));
      }
      return false;
    }
  }

  void _listen() {
    if (_liveSubs.isNotEmpty) return;
    _liveSubs.addAll([
      gateway.onTokenRefresh.listen((t) {
        unawaited(remote
            .register(
              token: t,
              platform: _platform(),
              appVersion: BuildInfo.fullVersion,
            )
            .catchError((_) {}));
      }),
      gateway.onForeground
          .listen((p) => _events.add(PushEvent(p, opened: false))),
      gateway.onOpened.listen((p) => _events.add(PushEvent(p, opened: true))),
    ]);
    unawaited(gateway.launchedBy().then((p) {
      if (p != null) _events.add(PushEvent(p, opened: true));
    }));
  }

  void _stopListening() {
    for (final s in _liveSubs) {
      s.cancel();
    }
    _liveSubs.clear();
  }

  @override
  Future<void> close() async {
    await _sessionSub?.cancel();
    _stopListening();
    await _events.close();
    return super.close();
  }
}
