import 'package:dio/dio.dart';
import '../../../../core/errors/api_exception.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/storage/session_store.dart';
import '../../../../core/storage/token_storage.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepository {
  int get generation => _sessionStore.generation;
  final AuthRemoteDatasource _remote;
  final TokenStorage _tokenStorage;
  final SessionStore _sessionStore;

  AuthRepository({
    required this._remote,
    required this._tokenStorage,
    required this._sessionStore,
  });

  Future<void> login({
    required String tenantSlug,
    required String email,
    required String password,
  }) async {
    final clear = _sessionStore.clear();
    final generation = _sessionStore.generation;
    await clear;
    if (generation != _sessionStore.generation) {
      throw const ApiException(
        code: 'cancelled',
        message: 'Connexion remplacée.',
      );
    }
    final res = await _remote.login(
      tenantSlug: tenantSlug,
      email: email,
      password: password,
    );
    final committed = await _sessionStore.commit(
      generation: generation,
      token: res.token,
      user: res.user.toJson(),
      tenant: res.tenant.toJson(),
      fallbackRole: res.user.role,
    );
    if (!committed) {
      throw const ApiException(
        code: 'cancelled',
        message: 'Connexion remplacée.',
      );
    }
  }

  Future<void> register({
    required String tenantName,
    required String tenantSlug,
    required String ownerName,
    required String ownerEmail,
    required String password,
  }) async {
    final clear = _sessionStore.clear();
    final generation = _sessionStore.generation;
    await clear;
    if (generation != _sessionStore.generation) {
      throw const ApiException(
        code: 'cancelled',
        message: 'Connexion remplacée.',
      );
    }
    final res = await _remote.register(
      tenantName: tenantName,
      tenantSlug: tenantSlug,
      ownerName: ownerName,
      ownerEmail: ownerEmail,
      password: password,
    );
    const role = 'owner';
    final committed = await _sessionStore.commit(
      generation: generation,
      token: res.token,
      user: res.user.copyWith(role: role).toJson(),
      tenant: res.tenant.toJson(),
      fallbackRole: role,
    );
    if (!committed) {
      throw const ApiException(
        code: 'cancelled',
        message: 'Connexion remplacée.',
      );
    }
  }

  Future<void> logout() async {
    final token = _sessionStore.token;
    await _sessionStore.clear();
    try {
      if (token != null) await _remote.logout(token: token);
    } catch (_) {
      // Backend unreachable — still wipe local state.
    }
  }

  Future<void> forgotPassword({required String email}) =>
      _remote.forgotPassword(email: email);

  Future<void> logoutEverywhere() async {
    final token = _sessionStore.token;
    await _sessionStore.clear();
    if (token != null) await _remote.logoutEverywhere(token: token);
  }

  /// Wipes local session state without calling the logout endpoint — for
  /// when the server has already told us the token is invalid (a real
  /// 401 `UNAUTHENTICATED`), where calling logout would just be a second,
  /// pointless request that would also 401.
  Future<void> clearLocalSession({int? expectedGeneration}) =>
      _sessionStore.clear(expectedGeneration: expectedGeneration);

  Future<bool> restoreSession() async {
    final generation = _sessionStore.generation;
    final token = await _tokenStorage.read();
    if (token == null || token.isEmpty) return false;
    try {
      final res = await _remote.me();
      if (generation != _sessionStore.generation) return false;
      await _sessionStore.set(
        user: res.user.toJson(),
        tenant: res.tenant.toJson(),
        fallbackRole: res.user.role,
      );
      return true;
    } catch (error) {
      final api = error is DioException ? ErrorMapper.fromDio(error) : error;
      if (api is ApiException && api.isUnauthenticated) {
        await _sessionStore.clear(expectedGeneration: generation);
        return false;
      }
      rethrow;
    }
  }
}
