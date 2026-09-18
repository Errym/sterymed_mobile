#!/usr/bin/env bash
# =============================================================================
# p1b_patient_local_cache.sh
# The backend /v1/patients endpoint only returns { id, reference }.
# Names, phone, email are NOT returned by the API — they were stored but
# the PatientData resource doesn't expose them.
#
# Fix: cache the full patient record locally, keyed by id, and merge it
# with whatever the API returns. This makes names/phones show up correctly
# and makes the edit sheet prefill correctly.
#
# Run from ~/sterymed_mobile
# =============================================================================
set -euo pipefail

ROOT="$(pwd)"
[[ -f "$ROOT/pubspec.yaml" ]] || { echo "❌ Not project root"; exit 1; }
grep -q "name: steriymed_mobile" "$ROOT/pubspec.yaml" || { echo "❌ Wrong project"; exit 1; }

echo "═══════════════════════════════════════════════════════════════"
echo "  P1b — Patient local cache (name/phone/email survive API)"
echo "═══════════════════════════════════════════════════════════════"

mkdir -p lib/features/patients/data/local

# ─────────────────────────────────────────────────────────────────────────────
# 1. Local cache for patient details the API refuses to return
# ─────────────────────────────────────────────────────────────────────────────
cat > lib/features/patients/data/local/patient_local_cache.dart << 'DART'
import 'dart:convert';

import 'package:hive/hive.dart';

import '../models/patient_data.dart';

/// The backend's /v1/patients endpoint returns ONLY { id, reference }.
/// All other fields (name, phone, email, birth_date) are stored server-side
/// but not returned. This class persists the full record locally so the app
/// can display what the user typed, and so the edit sheet can prefill.
///
/// Keyed by patient id. Nothing here is authoritative — the API is still the
/// source of truth for existence. This is only a "display" cache.
class PatientLocalCache {
  static const _boxName = 'steriymed.patient_cache';

  Box<dynamic>? _box;

  Future<void> _ensureBox() async {
    _box ??= await Hive.openBox(_boxName);
  }

  Future<void> save(PatientData patient) async {
    await _ensureBox();
    final payload = {
      'id': patient.id,
      'first_name': patient.firstName,
      'last_name': patient.lastName,
      'reference': patient.reference,
      'phone': patient.phone,
      'email': patient.email,
      'birth_date': patient.birthDate?.toIso8601String(),
    };
    await _box!.put(patient.id, jsonEncode(payload));
  }

  Future<void> saveAll(List<PatientData> patients) async {
    for (final p in patients) {
      await save(p);
    }
  }

  Future<PatientData?> get(String id) async {
    await _ensureBox();
    final raw = _box!.get(id);
    if (raw is! String) return null;
    try {
      final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
      return PatientData.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> remove(String id) async {
    await _ensureBox();
    await _box!.delete(id);
  }

  /// Merge: prefer the local cache for name/phone/email, but the API
  /// response is authoritative for existence and reference.
  Future<List<PatientData>> merge(
    List<PatientData> fromApi,
  ) async {
    await _ensureBox();
    final merged = <PatientData>[];
    for (final apiPatient in fromApi) {
      final cached = await get(apiPatient.id);
      if (cached == null) {
        // No local cache: patient came from another device/session.
        // Show what the API has (which is only id + reference).
        merged.add(apiPatient);
      } else {
        merged.add(
          PatientData(
            id: apiPatient.id,
            firstName: cached.firstName.isNotEmpty
                ? cached.firstName
                : apiPatient.firstName,
            lastName: cached.lastName.isNotEmpty
                ? cached.lastName
                : apiPatient.lastName,
            reference: apiPatient.reference ?? cached.reference,
            birthDate: cached.birthDate ?? apiPatient.birthDate,
            phone: cached.phone ?? apiPatient.phone,
            email: cached.email ?? apiPatient.email,
            createdAt: apiPatient.createdAt,
            updatedAt: apiPatient.updatedAt,
          ),
        );
      }
    }
    return merged;
  }
}
DART

echo "  ✔ patient_local_cache.dart"

# ─────────────────────────────────────────────────────────────────────────────
# 2. Rewrite the repository to use the cache
# ─────────────────────────────────────────────────────────────────────────────
cat > lib/features/patients/data/repositories/patient_repository.dart << 'DART'
import '../../../../core/cache/cache.dart';
import '../../../../core/utils/logger.dart';
import '../datasources/patient_remote_datasource.dart';
import '../local/patient_local_cache.dart';
import '../models/patient_create_request.dart';
import '../models/patient_data.dart';

class PatientRepository {
  final PatientRemoteDatasource _remote;
  final AppCache _cache;
  final PatientLocalCache _local;

  PatientRepository(this._remote, this._cache, this._local);

  Future<List<PatientData>> search(
    String query, {
    bool forceRefresh = false,
  }) async {
    // We don't cache the API list here — the local patient cache handles
    // the display values. Always hit the API so we reflect server changes.
    final fromApi = await _remote.search(query);
    // Merge with the local cache so name/phone/email show up.
    return _local.merge(fromApi);
  }

  Future<PatientData> create(PatientCreateRequest req) async {
    final created = await _remote.create(req);
    // The API only returns { id, reference }. Save the full record locally
    // so the name and other fields survive.
    final full = PatientData(
      id: created.id,
      firstName: req.firstName,
      lastName: req.lastName,
      reference: created.reference ?? req.reference,
      birthDate: req.birthDate,
      phone: req.phone,
      email: req.email,
    );
    await _local.save(full);
    _cache.invalidateAll();
    return full;
  }

  Future<PatientData> show(String id) async {
    // Prefer the local cache — it has the real values.
    final cached = await _local.get(id);
    if (cached != null) return cached;
    // Fall back to the API (which only has id + reference).
    return _remote.show(id);
  }

  Future<void> destroy(String id) async {
    await _remote.destroy(id);
    await _local.remove(id);
    _cache.invalidateAll();
  }

  /// Edit = delete + recreate (backend has no PATCH /v1/patients).
  /// We keep the local cache consistent through both steps.
  Future<PatientData> update({
    required String id,
    required PatientCreateRequest req,
  }) async {
    AppLogger.d('PatientRepository.update: delete + recreate for $id');
    await _remote.destroy(id);
    await _local.remove(id);
    final created = await _remote.create(req);
    final full = PatientData(
      id: created.id,
      firstName: req.firstName,
      lastName: req.lastName,
      reference: created.reference ?? req.reference,
      birthDate: req.birthDate,
      phone: req.phone,
      email: req.email,
    );
    await _local.save(full);
    _cache.invalidateAll();
    return full;
  }
}
DART

echo "  ✔ patient_repository.dart (uses local cache)"

# ─────────────────────────────────────────────────────────────────────────────
# 3. Register the cache in DI and pass it to the repository
# ─────────────────────────────────────────────────────────────────────────────
python - << 'PYEOF'
import io, pathlib

# 3a. Add the import + registration to features_di.dart
di_path = pathlib.Path('lib/di/features_di.dart')
di = di_path.read_text()

# Add import
if 'patient_local_cache.dart' not in di:
    di = di.replace(
        "import '../features/patients/data/datasources/patient_remote_datasource.dart';",
        "import '../features/patients/data/datasources/patient_remote_datasource.dart';\n"
        "import '../features/patients/data/local/patient_local_cache.dart';",
    )

# Add cache registration + pass to repository
if 'PatientLocalCache>' not in di:
    di = di.replace(
        "getIt.registerLazySingleton<PatientRepository>(() => PatientRepository(\n"
        "        getIt<PatientRemoteDatasource>(),\n"
        "        getIt<AppCache>(),\n"
        "      ));",
        "getIt.registerLazySingleton<PatientLocalCache>(() => PatientLocalCache());\n"
        "  getIt.registerLazySingleton<PatientRepository>(() => PatientRepository(\n"
        "        getIt<PatientRemoteDatasource>(),\n"
        "        getIt<AppCache>(),\n"
        "        getIt<PatientLocalCache>(),\n"
        "      ));",
    )

di_path.write_text(di)
print("  ✔ features_di.dart updated")
PYEOF

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  Verification"
echo "═══════════════════════════════════════════════════════════════"
flutter analyze 2>&1 | tee /tmp/p1b.txt | tail -25
echo ""
echo "  Errors: $(grep -c ' error •' /tmp/p1b.txt || echo 0)"