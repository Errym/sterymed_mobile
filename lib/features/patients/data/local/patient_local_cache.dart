// WORKAROUND: Backend GET /v1/patients returns only {id, reference}.
// Full record cached locally.
// See docs/MISSING_FEATURES.md. Remove when BACKEND_BUGS.md#bug-008 is fixed.

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
