import 'dart:convert';

import 'secure_storage.dart';

class SessionStore {
  static const _userKey = 'steriymed.session.user';
  static const _tenantKey = 'steriymed.session.tenant';
  static const _roleKey = 'steriymed.session.role';

  final SecureStorage _secure;
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _tenant;
  String? _fallbackRole;

  SessionStore(this._secure);

  Map<String, dynamic>? get user => _user;
  Map<String, dynamic>? get tenant => _tenant;
  bool get hasSession => _user != null && _tenant != null;

  String? get userId => _user?['id']?.toString();
  String? get userName => _user?['name']?.toString();
  String? get userEmail => _user?['email']?.toString();
  String? get tenantName => _tenant?['name']?.toString();
  String? get tenantSlug => _tenant?['slug']?.toString();

  String? get role {
    final direct = _user?['role']?.toString();
    if (direct != null && direct.isNotEmpty) return direct;
    return _fallbackRole;
  }

  bool get isOwner => role == 'owner' || role == 'admin';
  bool get isStaff => !isOwner;

  Future<void> load() async {
    final u = await _secure.read(_userKey);
    final t = await _secure.read(_tenantKey);
    final r = await _secure.read(_roleKey);
    if (u != null) _user = (jsonDecode(u) as Map).cast<String, dynamic>();
    if (t != null) _tenant = (jsonDecode(t) as Map).cast<String, dynamic>();
    _fallbackRole = r;
  }

  Future<void> set({
    required Map<String, dynamic> user,
    required Map<String, dynamic> tenant,
    String? fallbackRole,
  }) async {
    _user = user;
    _tenant = tenant;
    await _secure.write(_userKey, jsonEncode(user));
    await _secure.write(_tenantKey, jsonEncode(tenant));
    if (fallbackRole != null) {
      _fallbackRole = fallbackRole;
      await _secure.write(_roleKey, fallbackRole);
    }
  }

  Future<void> clear() async {
    _user = null;
    _tenant = null;
    _fallbackRole = null;
    await _secure.delete(_userKey);
    await _secure.delete(_tenantKey);
    await _secure.delete(_roleKey);
  }
}
