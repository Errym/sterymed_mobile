import 'dart:async';
import 'dart:convert';

import '../config/env.dart';
import 'secure_storage.dart';

/// A secure, versioned record keeps credentials and their owner together.
/// Generation changes fence requests belonging to an older login.
class SessionStore {
  static const recordKey = 'steriymed.session.v2';
  static const permissionLifetime = Duration(minutes: 15);
  final SecureStorage _secure;
  final _changes = StreamController<int>.broadcast(sync: true);
  Future<void> _writes = Future<void>.value();
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _tenant;
  String? _token;
  String? _fallbackRole;
  DateTime? _verifiedAt;
  bool _validated = false;
  int _generation = 0;

  SessionStore(this._secure);

  Stream<int> get changes => _changes.stream;
  int get generation => _generation;
  Map<String, dynamic>? get user =>
      _user == null ? null : Map.unmodifiable(_user!);
  Map<String, dynamic>? get tenant =>
      _tenant == null ? null : Map.unmodifiable(_tenant!);
  bool get hasSession => _user != null && _tenant != null;
  String? get token => _token;
  String? get userId => _user?['id']?.toString();
  String? get userName => _user?['name']?.toString();
  String? get userEmail => _user?['email']?.toString();
  String? get tenantId => _tenant?['id']?.toString();
  String? get tenantName => _tenant?['name']?.toString();
  String? get tenantSlug => _tenant?['slug']?.toString();
  String? get scopeKey => hasSession
      ? jsonEncode([Env.environment, Env.resolvedApiBaseUrl, tenantId, userId])
      : null;
  bool get permissionsFresh =>
      _verifiedAt != null &&
      DateTime.now().difference(_verifiedAt!) < permissionLifetime;
  bool get canSend =>
      hasSession && _validated && permissionsFresh && _token != null;

  String? get role {
    final direct = _user?['role']?.toString();
    return direct != null && direct.isNotEmpty ? direct : _fallbackRole;
  }

  bool get isOwner => role == 'owner' || role == 'admin';
  bool get isStaff => !isOwner;
  List<String> get permissions {
    if (!permissionsFresh) return const [];
    final raw = _user?['permissions'];
    return raw is List
        ? raw.whereType<String>().toList(growable: false)
        : const [];
  }

  bool hasPermission(String permission) => permissions.contains(permission);
  bool hasAnyPermission(Iterable<String> anyOf) =>
      anyOf.any(permissions.contains);

  static bool _validIdentity(
    Map<String, dynamic> user,
    Map<String, dynamic> tenant,
  ) =>
      (user['id']?.toString().isNotEmpty ?? false) &&
      (tenant['id']?.toString().isNotEmpty ?? false) &&
      user['permissions'] is List;

  Future<void> load() async {
    final expected = _generation;
    try {
      final raw = await _secure.read(recordKey);
      if (expected != _generation || raw == null) return;
      final value = jsonDecode(raw) as Map;
      final user = (value['user'] as Map).cast<String, dynamic>();
      final tenant = (value['tenant'] as Map).cast<String, dynamic>();
      final token = value['token'] as String;
      if (value['version'] != 2 ||
          value['environment'] != Env.environment ||
          value['api'] != Env.resolvedApiBaseUrl ||
          token.isEmpty ||
          !_validIdentity(user, tenant)) {
        return;
      }
      _user = user;
      _tenant = tenant;
      _token = token;
      _fallbackRole = value['role'] as String?;
      _verifiedAt = DateTime.tryParse(value['verifiedAt']?.toString() ?? '');
      _validated = false;
    } catch (_) {
      // Preserve corrupt/old secure bytes; login can replace them explicitly.
      if (expected == _generation) _forget();
    }
  }

  int beginReplacement() {
    _generation++;
    _forget();
    _changes.add(_generation);
    return _generation;
  }

  void _forget() {
    _user = null;
    _tenant = null;
    _token = null;
    _fallbackRole = null;
    _verifiedAt = null;
    _validated = false;
  }

  Future<void> _serialize(Future<void> Function() action) {
    final next = _writes.then((_) => action());
    _writes = next.catchError((Object _) {});
    return next;
  }

  Future<bool> commit({
    required int generation,
    required String token,
    required Map<String, dynamic> user,
    required Map<String, dynamic> tenant,
    String? fallbackRole,
  }) async {
    if (token.isEmpty || !_validIdentity(user, tenant)) {
      throw const FormatException('Session invalide. Reconnectez-vous.');
    }
    if (generation != _generation) return false;
    final verifiedAt = DateTime.now();
    final record = jsonEncode({
      'version': 2,
      'environment': Env.environment,
      'api': Env.resolvedApiBaseUrl,
      'token': token,
      'user': user,
      'tenant': tenant,
      'role': fallbackRole,
      'verifiedAt': verifiedAt.toIso8601String(),
    });
    await _serialize(() async {
      if (generation == _generation) await _secure.write(recordKey, record);
    });
    if (generation != _generation) return false;
    _user = Map<String, dynamic>.from(user);
    _tenant = Map<String, dynamic>.from(tenant);
    _token = token;
    _fallbackRole = fallbackRole;
    _verifiedAt = verifiedAt;
    _validated = true;
    _changes.add(_generation);
    return true;
  }

  Future<void> set({
    required Map<String, dynamic> user,
    required Map<String, dynamic> tenant,
    String? fallbackRole,
  }) async {
    final token = _token;
    if (token == null) throw StateError('Aucune session à actualiser.');
    if (user['id']?.toString() != userId ||
        tenant['id']?.toString() != tenantId) {
      throw const FormatException('Identité de session inattendue.');
    }
    await commit(
      generation: _generation,
      token: token,
      user: user,
      tenant: tenant,
      fallbackRole: fallbackRole,
    );
  }

  /// Releases the change stream. The store is an app-lifetime singleton;
  /// this exists for DI teardown and tests.
  Future<void> dispose() => _changes.close();

  Future<void> clear({int? expectedGeneration}) {
    if (expectedGeneration != null && expectedGeneration != _generation) {
      return Future<void>.value();
    }
    final generation = beginReplacement();
    return _serialize(() async {
      if (generation != _generation) return;
      await _secure.delete(recordKey);
      for (final key in [
        'steriymed.bearer',
        'steriymed.session.user',
        'steriymed.session.tenant',
        'steriymed.session.role',
      ]) {
        await _secure.delete(key);
      }
    });
  }
}
