import 'secure_storage.dart';

class TokenStorage {
  static const _key = 'steriymed.bearer';
  final SecureStorage _secure;

  TokenStorage(this._secure);

  Future<String?> read() => _secure.read(_key);
  Future<void> save(String token) => _secure.write(_key, token);
  Future<void> clear() => _secure.delete(_key);
}
