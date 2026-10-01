import '../../../../core/storage/key_value_store.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/storage/session_store.dart';

/// Personal device drafts. They are not part of the server's clinical record.
class CycleNotesCache {
  final Future<KeyValueStore> _store;
  final SessionStore _session;
  CycleNotesCache(SecureStorage secure, this._session)
    : _store = KeyValueStore.open(
        'steriymed.cycle_notes',
        secure: secure,
        ownerScope: () => _session.scopeKey,
      );

  Future<void> save(String cycleId, String notes) async {
    final generation = _session.generation;
    final store = await _store;
    if (generation != _session.generation) return;
    await store.set(cycleId, notes);
  }

  Future<String?> get(String cycleId) async {
    final generation = _session.generation;
    final store = await _store;
    if (generation != _session.generation) return null;
    return store.get(cycleId) as String?;
  }

  Future<void> remove(String cycleId) async {
    final generation = _session.generation;
    final store = await _store;
    if (generation == _session.generation) await store.delete(cycleId);
  }
}
