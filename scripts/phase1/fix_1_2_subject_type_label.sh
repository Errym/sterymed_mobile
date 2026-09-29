#!/usr/bin/env bash
source "$(dirname "$0")/_common.sh"

banner "FIX 1.2 — Robust subjectTypeLabel"

require_repo_root
require_clean_tree

NC="lib/features/compliance/data/models/non_conformity_data.dart"
AUDIT="lib/features/history/data/models/audit_event_data.dart"

backup_file "$NC"
backup_file "$AUDIT"

# ── non_conformity_data.dart ──────────────────────────────────────────
# Replace the subjectTypeLabel getter.
NC_NEW=$(cat <<'DART'
  static const _subjectTypeLabels = <String, String>{
    'App\\Domain\\Sterilization\\Models\\Cycle': 'Cycle',
    'App\\Domain\\Sterilization\\Models\\CycleItem': 'Instrument de cycle',
    'App\\Domain\\Labeling\\Models\\Label': 'Étiquette',
    'App\\Domain\\Catalog\\Models\\Product': 'Produit',
    'App\\Domain\\Purchasing\\Models\\Supplier': 'Fournisseur',
    'App\\Domain\\Purchasing\\Models\\PurchaseOrder': 'Commande',
    'App\\Domain\\Equipment\\Models\\Device': 'Appareil',
    'App\\Domain\\Equipment\\Models\\MaintenanceRecord': 'Maintenance',
    'App\\Domain\\Reporting\\Models\\DataExportRequest': 'Export',
    'App\\Models\\User': 'Utilisateur',
  };

  String get subjectTypeLabel {
    final mapped = _subjectTypeLabels[subjectType];
    if (mapped != null) return mapped;
    if (subjectType.isEmpty) return '—';
    final last = subjectType.split('\\').last;
    return last.replaceAllMapped(
      RegExp(r'(?<=[a-z])(?=[A-Z])'),
      (_) => ' ',
    );
  }
DART
)

replace_block "$NC" \
  "  String get subjectTypeLabel =>" \
  "      subjectType == 'Cycle' ? 'Cycle' : 'Étiquette';" \
  "$NC_NEW"

# ── audit_event_data.dart ─────────────────────────────────────────────
# Only replace the fallback return line — the map is fine.
AUDIT_NEW=$(cat <<'DART'
    if (subjectType == null || subjectType!.isEmpty) return null;
    final mapped = _subjectTypeLabels[subjectType];
    if (mapped != null) return mapped;
    final last = subjectType!.split('\\').last;
    return last.replaceAllMapped(
      RegExp(r'(?<=[a-z])(?=[A-Z])'),
      (_) => ' ',
    );
  }
DART
)

# Match the existing getter block:
#   String? get subjectTypeLabel {
#     const map = {...};
#     if (subjectType == null) return null;
#     return map[subjectType] ?? subjectType;
#   }
START="  String? get subjectTypeLabel {"
END="    return map[subjectType] ?? subjectType;"
replace_block "$AUDIT" "$START" "$END" "$AUDIT_NEW"

run_analyze
commit_fix "fix(models): humanize subjectType fallback — never show raw class names" "$NC" "$AUDIT"

ok "FIX 1.2 complete"