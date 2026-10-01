import 'package:get_it/get_it.dart';
import 'package:steriymed_mobile/features/cycles/data/local/cycle_notes_cache.dart';

/// In-memory stand-in for the owner-scoped, encrypted [CycleNotesCache].
/// Widget tests must not open real Hive/secure-storage boxes.
class FakeCycleNotesCache implements CycleNotesCache {
  final Map<String, String> _notes = {};

  @override
  Future<String?> get(String cycleId) async => _notes[cycleId];

  @override
  Future<void> save(String cycleId, String notes) async =>
      _notes[cycleId] = notes;

  @override
  Future<void> remove(String cycleId) async => _notes.remove(cycleId);
}

/// (Re)registers a fresh [FakeCycleNotesCache] in GetIt.
void registerFakeCycleNotesCache() {
  final di = GetIt.instance;
  if (di.isRegistered<CycleNotesCache>()) di.unregister<CycleNotesCache>();
  di.registerSingleton<CycleNotesCache>(FakeCycleNotesCache());
}
