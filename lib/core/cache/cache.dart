class CacheEntry<T> {
  final T value;
  final DateTime storedAt;
  CacheEntry(this.value) : storedAt = DateTime.now();
}

class AppCache {
  final String? Function()? _ownerScope;
  String? _lastScope;
  AppCache({this._ownerScope});
  void _checkScope() {
    if (_ownerScope == null) return;
    final current = _ownerScope();
    if (current != _lastScope) _store.clear();
    _lastScope = current;
  }

  final Map<String, CacheEntry<dynamic>> _store = {};
  final Map<String, Duration> _ttls = {
    'dashboard': const Duration(seconds: 30),
    'alerts': const Duration(seconds: 20),
    'cycles': const Duration(seconds: 15),
    'stock_levels': const Duration(seconds: 30),
    'audit': const Duration(seconds: 60),
    'patients': const Duration(seconds: 120),
    'sites': const Duration(minutes: 5),
    'team': const Duration(minutes: 2),
    'non_conformities': const Duration(seconds: 30),
    'purchase_orders': const Duration(seconds: 30),
    'suppliers': const Duration(minutes: 2),
    'devices': const Duration(minutes: 1),
    'data_exports': const Duration(seconds: 30),
  };

  T? get<T>(String key) {
    _checkScope();
    final entry = _store[key];
    if (entry == null) return null;
    final ttl = _ttls[key] ?? const Duration(seconds: 30);
    if (DateTime.now().difference(entry.storedAt) > ttl) {
      _store.remove(key);
      return null;
    }
    return entry.value is T ? entry.value as T : null;
  }

  void put(String key, dynamic value) {
    _checkScope();
    if (_ownerScope != null && _lastScope == null) return;
    _store[key] = CacheEntry(value);
  }

  void invalidate(String key) => _store.remove(key);
  void invalidateAll() => _store.clear();
}
