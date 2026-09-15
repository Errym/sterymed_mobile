class SessionStore {
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _tenant;

  Map<String, dynamic>? get user => _user;
  Map<String, dynamic>? get tenant => _tenant;

  bool get hasSession => _user != null && _tenant != null;

  void set({
    required Map<String, dynamic> user,
    required Map<String, dynamic> tenant,
  }) {
    _user = user;
    _tenant = tenant;
  }

  void clear() {
    _user = null;
    _tenant = null;
  }

  String? get role {
    final r = _user?['role'];
    return r?.toString();
  }
}
