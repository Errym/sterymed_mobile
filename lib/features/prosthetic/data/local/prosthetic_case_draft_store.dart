import 'dart:convert';

import '../../../../core/storage/key_value_store.dart';

/// Autosaved in-progress create-case form input (brief page 14: "avoid
/// silent data loss" across a temporary connectivity loss) — same pattern
/// as `LabelUsageDraftStore`. Single slot (one draft at a time), since
/// only one create form can be open at once.
class ProstheticCaseDraft {
  final String? patientId;
  final String? patientReference;
  final String? practitionerId;
  final String? laboratoryId;
  final String impressionType;
  final String workType;
  final DateTime? impressionDate;
  final String priority;
  final String notes;
  final String internalComments;

  const ProstheticCaseDraft({
    this.patientId,
    this.patientReference,
    this.practitionerId,
    this.laboratoryId,
    this.impressionType = 'digital',
    this.workType = 'crown',
    this.impressionDate,
    this.priority = '',
    this.notes = '',
    this.internalComments = '',
  });

  bool get isEmpty =>
      patientId == null &&
      practitionerId == null &&
      laboratoryId == null &&
      priority.isEmpty &&
      notes.isEmpty &&
      internalComments.isEmpty;

  Map<String, dynamic> toJson() => {
        'patientId': patientId,
        'patientReference': patientReference,
        'practitionerId': practitionerId,
        'laboratoryId': laboratoryId,
        'impressionType': impressionType,
        'workType': workType,
        'impressionDate': impressionDate?.toIso8601String(),
        'priority': priority,
        'notes': notes,
        'internalComments': internalComments,
      };

  factory ProstheticCaseDraft.fromJson(Map<String, dynamic> json) =>
      ProstheticCaseDraft(
        patientId: json['patientId'] as String?,
        patientReference: json['patientReference'] as String?,
        practitionerId: json['practitionerId'] as String?,
        laboratoryId: json['laboratoryId'] as String?,
        impressionType: json['impressionType'] as String? ?? 'digital',
        workType: json['workType'] as String? ?? 'crown',
        impressionDate: json['impressionDate'] != null
            ? DateTime.tryParse(json['impressionDate'] as String)
            : null,
        priority: json['priority'] as String? ?? '',
        notes: json['notes'] as String? ?? '',
        internalComments: json['internalComments'] as String? ?? '',
      );
}

class ProstheticCaseDraftStore {
  static const _key = 'prosthetic_case_create_draft';

  final KeyValueStore _kv;
  ProstheticCaseDraftStore(this._kv);

  ProstheticCaseDraft? load() {
    final raw = _kv.get(_key) as String?;
    if (raw == null) return null;
    try {
      return ProstheticCaseDraft.fromJson(
        (jsonDecode(raw) as Map).cast<String, dynamic>(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save(ProstheticCaseDraft draft) {
    if (draft.isEmpty) return clear();
    return _kv.set(_key, jsonEncode(draft.toJson()));
  }

  Future<void> clear() => _kv.delete(_key);
}
