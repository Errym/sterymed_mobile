class CacheEntry<T> {
  final T value;
  final DateTime storedAt;
  CacheEntry(this.value) : storedAt = DateTime.now();
}

class AppCache {
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
    final entry = _store[key];
    if (entry == null) return null;
    final ttl = _ttls[key] ?? const Duration(seconds: 30);
    if (DateTime.now().difference(entry.storedAt) > ttl) {
      _store.remove(key);
      return null;
    }
    return entry.value as T;
  }

  void put(String key, dynamic value) {
    _store[key] = CacheEntry(value);
  }

  void invalidate(String key) => _store.remove(key);
  void invalidateAll() => _store.clear();
}
