import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Asks the device itself (fingerprint, face, PIN, pattern) who is holding it.
abstract class DeviceAuthenticator {
  /// False when the device has no screen lock at all: nothing to ask.
  Future<bool> isSupported();
  Future<bool> authenticate(String reason);
}

class LocalDeviceAuthenticator implements DeviceAuthenticator {
  final LocalAuthentication _auth;
  LocalDeviceAuthenticator([LocalAuthentication? auth])
      : _auth = auth ?? LocalAuthentication();

  @override
  Future<bool> isSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        // PIN, pattern and password are accepted, not only biometrics: a
        // gloved hand or a wet finger must still be able to unlock.
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } on PlatformException {
      return false;
    }
  }
}

/// Locks the app when it comes back after [timeout] in the background.
///
/// Surgery devices are shared and left on counters. A phone that was set down
/// for a few minutes must not open straight onto patient references, so the
/// user has to prove they are the person holding it. Quick app switches
/// (under the timeout) never ask.
///
/// A device with no screen lock cannot be asked anything, so after the
/// timeout the user is signed out instead. Their unsent work stays in the
/// encrypted storage of their own account.
class InactivityLock extends ChangeNotifier with WidgetsBindingObserver {
  final Duration timeout;
  final bool Function() isSignedIn;
  final DeviceAuthenticator authenticator;
  final VoidCallback onNoDeviceLock;
  final DateTime Function() _now;

  DateTime? _backgroundedAt;
  bool _locked = false;
  bool _unlocking = false;

  InactivityLock({
    required this.timeout,
    required this.isSignedIn,
    required this.authenticator,
    required this.onNoDeviceLock,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  bool get locked => _locked;

  /// Starts listening to the app lifecycle.
  void attach() => WidgetsBinding.instance.addObserver(this);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        // `inactive` is not enough: a permission dialog or a pulled-down
        // notification shade also makes the app inactive.
        _backgroundedAt ??= _now();
      case AppLifecycleState.resumed:
        _onResumed();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _onResumed() async {
    final since = _backgroundedAt;
    _backgroundedAt = null;
    if (since == null || !isSignedIn() || _locked) return;
    if (_now().difference(since) < timeout) return;
    if (await authenticator.isSupported()) {
      _locked = true;
      notifyListeners();
    } else {
      onNoDeviceLock();
    }
  }

  /// Asks the device to unlock. True when the app is open again.
  Future<bool> unlock({String reason = 'Déverrouillez SteryMed'}) async {
    if (!_locked) return true;
    if (_unlocking) return false;
    _unlocking = true;
    try {
      final ok = await authenticator.authenticate(reason);
      if (ok) {
        _locked = false;
        notifyListeners();
      }
      return ok;
    } finally {
      _unlocking = false;
    }
  }

  /// Leaves the lock screen without unlocking (the user signs out instead).
  void clear() {
    if (!_locked) return;
    _locked = false;
    notifyListeners();
  }
}
