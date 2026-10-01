import 'secure_storage.dart';
import 'session_store.dart';

class TokenStorage {
  static const _key = 'steriymed.bearer';
  final SecureStorage _secure;
  final SessionStore? _session;

  TokenStorage(this._secure, {this._session});

  Future<String?> read() async =>
      _session != null ? _session.token : _secure.read(_key);
  Future<void> save(String token) => _secure.write(_key, token);
  Future<void> clear() => _secure.delete(_key);
}
