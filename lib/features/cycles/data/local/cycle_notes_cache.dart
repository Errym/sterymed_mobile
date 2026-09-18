// WORKAROUND: Backend has no PATCH /v1/cycles/{id}.
// Notes cached in Hive only, never synced.
// See docs/MISSING_FEATURES.md. Remove when BACKEND_BUGS.md#bug-007 is fixed.

import 'dart:convert';

import 'package:hive/hive.dart';

/// The backend has no PATCH /v1/cycles/{id} endpoint, so cycle notes
/// cannot be edited server-side. This local cache persists them by cycle id
/// so the user can add/edit notes and see them across app restarts.
///
/// This is a display convenience — the server-side "notes" field set at
/// creation time remains immutable. Any note typed here lives only on this
/// device.
class CycleNotesCache {
  static const _boxName = 'steriymed.cycle_notes';

  Box<dynamic>? _box;

  Future<void> _ensureBox() async {
    _box ??= await Hive.openBox(_boxName);
  }

  Future<void> save(String cycleId, String notes) async {
    await _ensureBox();
    await _box!.put(cycleId, jsonEncode({'notes': notes}));
  }

  Future<String?> get(String cycleId) async {
    await _ensureBox();
    final raw = _box!.get(cycleId);
    if (raw is! String) return null;
    try {
      final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
      return map['notes']?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<void> remove(String cycleId) async {
    await _ensureBox();
    await _box!.delete(cycleId);
  }
}
