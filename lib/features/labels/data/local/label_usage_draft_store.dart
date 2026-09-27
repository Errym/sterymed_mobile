import 'dart:convert';

import '../../../../core/storage/key_value_store.dart';
import '../../../patients/data/models/patient_data.dart';

/// Autosaved in-progress LabelUsageFormScreen input, keyed per label so
/// returning to the same label's form (after an app kill, a crash, or
/// just navigating away and back) restores exactly where the user left
/// off. Cleared only on a successful submit — Phase 5's "never lose
/// input" requirement.
class LabelUsageDraft {
  final String? patientId;
  final String? patientReference;
  final String procedure;
  final String notes;

  const LabelUsageDraft({
    this.patientId,
    this.patientReference,
    this.procedure = '',
    this.notes = '',
  });

  /// Patients carry no PII (see docs/BACKEND_BUGS.md#bug-008) — the
  /// reference is an anonymous pseudonym, safe to keep in a local draft.
  PatientData? get patient => patientId == null
      ? null
      : PatientData(id: patientId!, reference: patientReference ?? '');

  bool get isEmpty =>
      patientId == null && procedure.isEmpty && notes.isEmpty;

  Map<String, dynamic> toJson() => {
        'patientId': patientId,
        'patientReference': patientReference,
        'procedure': procedure,
        'notes': notes,
      };

  factory LabelUsageDraft.fromJson(Map<String, dynamic> json) =>
      LabelUsageDraft(
        patientId: json['patientId'] as String?,
        patientReference: json['patientReference'] as String?,
        procedure: json['procedure'] as String? ?? '',
        notes: json['notes'] as String? ?? '',
      );
}

class LabelUsageDraftStore {
  final KeyValueStore _kv;
  LabelUsageDraftStore(this._kv);

  String _key(String labelId) => 'label_usage_draft:$labelId';

  LabelUsageDraft? load(String labelId) {
    final raw = _kv.get(_key(labelId)) as String?;
    if (raw == null) return null;
    try {
      return LabelUsageDraft.fromJson(
        (jsonDecode(raw) as Map).cast<String, dynamic>(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String labelId, LabelUsageDraft draft) {
    if (draft.isEmpty) return clear(labelId);
    return _kv.set(_key(labelId), jsonEncode(draft.toJson()));
  }

  Future<void> clear(String labelId) => _kv.delete(_key(labelId));
}
