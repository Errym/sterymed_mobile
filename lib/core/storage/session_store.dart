import 'dart:convert';

import 'secure_storage.dart';

class SessionStore {
  static const _userKey = 'steriymed.session.user';
  static const _tenantKey = 'steriymed.session.tenant';

  final SecureStorage _secure;
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _tenant;

  SessionStore(this._secure);

  Map<String, dynamic>? get user => _user;
  Map<String, dynamic>? get tenant => _tenant;
  bool get hasSession => _user != null && _tenant != null;

  String? get role => _user?['role']?.toString();
  String? get userId => _user?['id']?.toString();
  String? get userName => _user?['name']?.toString();
  String? get userEmail => _user?['email']?.toString();
  String? get tenantName => _tenant?['name']?.toString();
  String? get tenantSlug => _tenant?['slug']?.toString();

  Future<void> load() async {
    final u = await _secure.read(_userKey);
    final t = await _secure.read(_tenantKey);
    if (u == null || t == null) return;
    _user = (jsonDecode(u) as Map).cast<String, dynamic>();
    _tenant = (jsonDecode(t) as Map).cast<String, dynamic>();
  }

  Future<void> set({
    required Map<String, dynamic> user,
    required Map<String, dynamic> tenant,
  }) async {
    _user = user;
    _tenant = tenant;
    await _secure.write(_userKey, jsonEncode(user));
    await _secure.write(_tenantKey, jsonEncode(tenant));
  }

  Future<void> clear() async {
    _user = null;
    _tenant = null;
    await _secure.delete(_userKey);
    await _secure.delete(_tenantKey);
  }
}
