import '../../../../core/storage/session_store.dart';
import '../../../../core/storage/token_storage.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/login_response.dart';

class AuthRepository {
  final AuthRemoteDatasource _remote;
  final TokenStorage _tokenStorage;
  final SessionStore _sessionStore;

  AuthRepository({
    required AuthRemoteDatasource remote,
    required TokenStorage tokenStorage,
    required SessionStore sessionStore,
  }) : _remote = remote,
       _tokenStorage = tokenStorage,
       _sessionStore = sessionStore;

  Future<void> login({
    required String tenantSlug,
    required String email,
    required String password,
  }) async {
    final LoginResponse res = await _remote.login(
      tenantSlug: tenantSlug,
      email: email,
      password: password,
    );

    await _tokenStorage.save(res.token);
    _sessionStore.set(user: res.user.toJson(), tenant: res.tenant.toJson());
  }

  Future<void> logout() async {
    try {
      await _remote.logout();
    } finally {
      await _tokenStorage.clear();
      _sessionStore.clear();
    }
  }

  Future<void> logoutEverywhere() async {
    try {
      await _remote.logoutEverywhere();
    } finally {
      await _tokenStorage.clear();
      _sessionStore.clear();
    }
  }

  /// Attempts to restore a session from an existing token.
  /// Returns true if the token is valid.
  Future<bool> restoreSession() async {
    final token = await _tokenStorage.read();
    if (token == null || token.isEmpty) return false;

    try {
      final res = await _remote.me();
      _sessionStore.set(user: res.user.toJson(), tenant: res.tenant.toJson());
      return true;
    } catch (_) {
      await _tokenStorage.clear();
      _sessionStore.clear();
      return false;
    }
  }
  Future<void> register({
  required String tenantName,
  required String tenantSlug,
  required String ownerName,
  required String ownerEmail,
  required String password,
}) async {
  final LoginResponse res = await _remote.register(
    tenantName: tenantName,
    tenantSlug: tenantSlug,
    ownerName: ownerName,
    ownerEmail: ownerEmail,
    password: password,
  );

  await _tokenStorage.save(res.token);
  _sessionStore.set(user: res.user.toJson(), tenant: res.tenant.toJson());
}
}
