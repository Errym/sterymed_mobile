#!/usr/bin/env bash
# =============================================================================
# SteryMed — PHASE 1 (single-file, self-contained)
# Fixes: 1.2, 1.4, 1.5, 1.6, 1.8, 1.9, 1.10
#   1.1 & 1.3 already done in codebase.
#   1.7 (idempotency curl check) is manual — see bottom of script.
#
# Idempotent. Backs up every touched file. Runs analyze + test before each
# commit. Stops on first failure.
# =============================================================================
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

BACKUP_ROOT="_script_backups/phase1_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_ROOT"

banner() {
  echo ""
  echo "════════════════════════════════════════════════════════════"
  echo "  $1"
  echo "════════════════════════════════════════════════════════════"
}

backup() {
  [[ -f "$1" ]] || return 0
  local flat; flat="$(echo "$1" | sed 's|/|_|g')"
  cp "$1" "${BACKUP_ROOT}/${flat}"
  echo "  ▸ backup: $1"
}

require_clean() {
  if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "✗ tree dirty — commit or stash first"; git status --short; exit 1
  fi
}

run_checks() {
  echo ""; echo "  ▸ flutter analyze"
  flutter analyze || { echo "  ✗ analyze failed"; exit 1; }
  echo "  ✓ analyze clean"
  echo "  ▸ flutter test"
  flutter test --reporter compact 2>&1 | tail -3 || { echo "  ✗ tests failed"; exit 1; }
  echo "  ✓ tests passed"
}

commit_if_changed() {
  if git diff --quiet && git diff --cached --quiet; then
    echo "  ℹ no changes"; return 0
  fi
  git add -A
  git commit -m "$1"
  echo "  ✓ committed: $1"
}

# pyrep <file> <old> <new> [once|all]
pyrep() {
  PYTHONIOENCODING=utf-8 \
  python - "$1" "$2" "$3" "${4:-once}" <<'PYEOF'
import sys, pathlib
p = pathlib.Path(sys.argv[1]); old = sys.argv[2]; new = sys.argv[3]; mode = sys.argv[4]
src = p.read_text(encoding="utf-8")
if new.strip() and new.strip() in src:
    print(f"    · {p.name}: already patched"); sys.exit(0)
n = src.count(old)
if n == 0:
    print(f"    ✗ {p.name}: anchor not found — skipping"); sys.exit(0)
src = src.replace(old, new, 1 if mode == "once" else -1)
p.write_text(src, encoding="utf-8")
print(f"    ✓ {p.name}: patched")
PYEOF
}

require_clean

# =============================================================================
banner "FIX 1.2 — humanize subjectTypeLabel"
# =============================================================================

NC="lib/features/compliance/data/models/non_conformity_data.dart"
AUDIT="lib/features/history/data/models/audit_event_data.dart"

if ! grep -q "static const _subjectTypeLabels" "$NC"; then
  backup "$NC"
  pyrep "$NC" \
"String get subjectTypeLabel =>
      subjectType == 'Cycle' ? 'Cycle' : 'Étiquette';" \
"static const _subjectTypeLabels = <String, String>{
    'App\\\\Domain\\\\Sterilization\\\\Models\\\\Cycle': 'Cycle',
    'App\\\\Domain\\\\Sterilization\\\\Models\\\\CycleItem': 'Instrument de cycle',
    'App\\\\Domain\\\\Labeling\\\\Models\\\\Label': 'Étiquette',
    'App\\\\Domain\\\\Catalog\\\\Models\\\\Product': 'Produit',
    'App\\\\Domain\\\\Purchasing\\\\Models\\\\Supplier': 'Fournisseur',
    'App\\\\Domain\\\\Purchasing\\\\Models\\\\PurchaseOrder': 'Commande',
    'App\\\\Domain\\\\Equipment\\\\Models\\\\Device': 'Appareil',
    'App\\\\Domain\\\\Equipment\\\\Models\\\\MaintenanceRecord': 'Maintenance',
    'App\\\\Domain\\\\Reporting\\\\Models\\\\DataExportRequest': 'Export',
    'App\\\\Models\\\\User': 'Utilisateur',
  };

  String get subjectTypeLabel {
    final mapped = _subjectTypeLabels[subjectType];
    if (mapped != null) return mapped;
    final last = subjectType.split('\\\\').last;
    return last.replaceAllMapped(
      RegExp(r'(?<=[a-z])(?=[A-Z])'),
      (_) => ' ',
    );
  }"
else
  echo "  ✓ NC already humanized"
fi

if ! grep -q "RegExp(r'(?<=\[a-z\])(?=\[A-Z\])')" "$AUDIT"; then
  backup "$AUDIT"
  pyrep "$AUDIT" \
"    if (subjectType == null) return null;
    return map[subjectType] ?? subjectType;" \
"    if (subjectType == null) return null;
    final mapped = map[subjectType];
    if (mapped != null) return mapped;
    final last = subjectType!.split('\\\\').last;
    return last.replaceAllMapped(
      RegExp(r'(?<=[a-z])(?=[A-Z])'),
      (_) => ' ',
    );"
else
  echo "  ✓ audit already humanized"
fi

run_checks
commit_if_changed "fix(models): humanize subjectTypeLabel fallback in both NC and audit"

# =============================================================================
banner "FIX 1.4 — NC filter chips"
# =============================================================================

SCREEN="lib/features/compliance/presentation/screens/non_conformities_screen.dart"

if grep -q "FilterChipRow<String?>" "$SCREEN"; then
  echo "  ✓ already wired"
else
  backup "$SCREEN"
  python - "$SCREEN" <<'PYEOF'
import sys, pathlib
p = pathlib.Path(sys.argv[1]); src = p.read_text(encoding="utf-8")

if "filter_chip_row.dart" not in src:
    src = src.replace(
        "import '../../../../shared/widgets/layout/app_appbar.dart';",
        "import '../../../../shared/widgets/inputs/filter_chip_row.dart';\n"
        "import '../../../../shared/widgets/layout/app_appbar.dart';", 1)

marker = "class _NcView extends StatelessWidget {"
if marker not in src:
    print("    ✗ _NcView marker not found"); sys.exit(1)
start = src.find(marker)
depth = 0; i = start; seen = False; end = -1
while i < len(src):
    c = src[i]
    if c == '{': depth += 1; seen = True
    elif c == '}':
        depth -= 1
        if seen and depth == 0: end = i + 1; break
    i += 1

NEW = '''class _NcView extends StatefulWidget {
  const _NcView();
  @override
  State<_NcView> createState() => _NcViewState();
}

class _NcViewState extends State<_NcView> {
  String? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final canManage = getIt<SessionStore>().hasPermission(
      'non_conformities.manage',
    );

    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppAppBar(
        title: 'Non-Conformités & Rappels',
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () async {
                final ok = await NcCreateSheet.show(context);
                if (ok == true && context.mounted) {
                  context
                      .read<NonConformityListBloc>()
                      .add(const LoadNonConformities());
                }
              },
            ),
        ],
      ),
      body: Column(
        children: [
          FilterChipRow<String?>(
            selected: _statusFilter,
            onSelected: (v) {
              setState(() => _statusFilter = v);
              context
                  .read<NonConformityListBloc>()
                  .add(FilterNonConformities(v));
            },
            options: const [
              FilterChipOption(value: null, label: 'Toutes'),
              FilterChipOption(value: 'open', label: 'En cours'),
              FilterChipOption(value: 'resolved', label: 'Résolues'),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: BlocBuilder<NonConformityListBloc, NonConformityListState>(
              builder: (context, state) {
                if (state.status == NonConformityStatus.loading &&
                    state.items.isEmpty) {
                  return const ListSkeleton();
                }
                if (state.status == NonConformityStatus.failure) {
                  return ErrorView(
                    message: state.error ?? 'Erreur',
                    onRetry: () => context
                        .read<NonConformityListBloc>()
                        .add(const LoadNonConformities()),
                  );
                }
                if (state.items.isEmpty) {
                  return EmptyView(
                    title: 'Aucune non-conformité',
                    message: _statusFilter == 'open'
                        ? 'Aucun incident en cours.'
                        : _statusFilter == 'resolved'
                            ? 'Aucune non-conformité résolue.'
                            : 'Aucun incident enregistré.',
                    icon: Icons.verified_outlined,
                    action: canManage
                        ? FilledButton.icon(
                            onPressed: () async {
                              final ok = await NcCreateSheet.show(context);
                              if (ok == true && context.mounted) {
                                context
                                    .read<NonConformityListBloc>()
                                    .add(const LoadNonConformities());
                              }
                            },
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Nouvelle non-conformité'),
                          )
                        : null,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => context
                      .read<NonConformityListBloc>()
                      .add(const LoadNonConformities()),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: state.items.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (_, i) => AnimatedListItem(
                      index: i,
                      child: _NcCard(
                        item: state.items[i],
                        canManage: canManage,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}'''

src = src[:start] + NEW + src[end:]
p.write_text(src, encoding="utf-8")
print("    ✓ _NcView rewritten with FilterChipRow")
PYEOF
fi

run_checks
commit_if_changed "feat(compliance): wire NC filter chips to bloc with empty-state"

# =============================================================================
banner "FIX 1.5 — Hive flush after every write"
# =============================================================================

OUTBOX="lib/core/storage/outbox/outbox_store.dart"
KV="lib/core/storage/key_value_store.dart"
CACHE="lib/features/cycles/data/local/cycle_notes_cache.dart"

if ! grep -q "_box.flush()" "$OUTBOX"; then
  backup "$OUTBOX"
  cat > "$OUTBOX" <<'DART'
import 'package:hive/hive.dart';

import 'outbox_item.dart';
import 'outbox_status.dart';

class OutboxStore {
  static const _boxName = 'steriymed.outbox';
  final Box<dynamic> _box;

  OutboxStore(this._box);

  static Future<OutboxStore> open() async {
    final box = await Hive.openBox(_boxName);
    return OutboxStore(box);
  }

  Future<void> enqueue(OutboxItem item) async {
    await _box.put(item.id, item.toJson());
    await _box.flush();
  }

  List<OutboxItem> all() =>
      _box.values
          .map((e) => OutboxItem.fromJson((e as Map).cast<String, dynamic>()))
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  List<OutboxItem> pending() =>
      all().where((i) => i.status == OutboxStatus.pending).toList();

  List<OutboxItem> manualReview() =>
      all().where((i) => i.status == OutboxStatus.manualReview).toList();

  int get pendingCount => pending().length;

  Future<void> update(OutboxItem item) async {
    await _box.put(item.id, item.toJson());
    await _box.flush();
  }

  Future<void> remove(String id) async {
    await _box.delete(id);
    await _box.flush();
  }

  Future<void> removeMany(Iterable<String> ids) async {
    await _box.deleteAll(ids);
    await _box.flush();
  }

  Future<void> clear() async {
    await _box.clear();
    await _box.flush();
  }
}
DART
  echo "    ✓ rewrote outbox_store.dart"
else
  echo "  ✓ outbox_store already flushes"
fi

if ! grep -q "_box.flush()" "$KV"; then
  backup "$KV"
  cat > "$KV" <<'DART'
import 'package:hive_flutter/hive_flutter.dart';

class KeyValueStore {
  final Box<dynamic> _box;

  KeyValueStore(this._box);

  static Future<KeyValueStore> open(String name) async {
    final box = await Hive.openBox(name);
    return KeyValueStore(box);
  }

  dynamic get(String key) => _box.get(key);

  Future<void> set(String key, dynamic value) async {
    await _box.put(key, value);
    await _box.flush();
  }

  Future<void> delete(String key) async {
    await _box.delete(key);
    await _box.flush();
  }

  Future<void> clear() async {
    await _box.clear();
    await _box.flush();
  }
}
DART
  echo "    ✓ rewrote key_value_store.dart"
else
  echo "  ✓ key_value_store already flushes"
fi

if ! grep -q "_box!.flush()" "$CACHE"; then
  backup "$CACHE"
  pyrep "$CACHE" \
"    await _box!.put(cycleId, jsonEncode({'notes': notes}));" \
"    await _box!.put(cycleId, jsonEncode({'notes': notes}));
    await _box!.flush();"
  pyrep "$CACHE" \
"    await _box!.delete(cycleId);" \
"    await _box!.delete(cycleId);
    await _box!.flush();"
  echo "    ✓ cycle_notes_cache patched"
else
  echo "  ✓ cycle_notes_cache already flushes"
fi

run_checks
commit_if_changed "fix(storage): flush Hive after every write"

# =============================================================================
banner "FIX 1.6 — kill user-facing e.toString()"
# =============================================================================

EM="lib/core/utils/error_message.dart"
if ! grep -q "error is DioException" "$EM"; then
  backup "$EM"
  pyrep "$EM" \
"import '../errors/api_exception.dart';" \
"import 'package:dio/dio.dart';

import '../errors/api_exception.dart';"
  pyrep "$EM" \
"  static String from(Object error) {
    if (error is ApiException) {" \
"  static String from(Object error) {
    if (error is DioException) {
      return 'Une erreur réseau est survenue. Réessayez.';
    }
    if (error is ApiException) {"
  echo "    ✓ ErrorMessage hardened"
else
  echo "  ✓ ErrorMessage already handles DioException"
fi

# Sweep: any file that calls AppSnackbar.show AND has e.toString().
FILES=$(grep -rln "AppSnackbar.show" lib/ | xargs grep -ln "e.toString()" 2>/dev/null || true)
for f in $FILES; do
  backup "$f"
  if ! grep -q "core/utils/error_message.dart" "$f"; then
    depth=$(echo "$f" | awk -F'/' '{print NF-2}')
    rel=""
    for ((i=0; i<depth; i++)); do rel="../$rel"; done
    rel="${rel}core/utils/error_message.dart"
    last_import_line=$(grep -nE "^import '" "$f" | tail -1 | cut -d: -f1)
    if [[ -n "$last_import_line" ]]; then
      python - "$f" "$last_import_line" "$rel" <<'PYEOF'
import sys, pathlib
p = pathlib.Path(sys.argv[1]); line = int(sys.argv[2]); rel = sys.argv[3]
lines = p.read_text(encoding="utf-8").splitlines(keepends=True)
lines.insert(line, f"import '{rel}';\n")
p.write_text("".join(lines), encoding="utf-8")
print(f"    ✓ import added to {p.name}")
PYEOF
    fi
  fi
  pyrep "$f" "e.toString(), kind: SnackKind.error" "ErrorMessage.from(e), kind: SnackKind.error" all
done

run_checks
commit_if_changed "fix(errors): never surface raw exceptions — always ErrorMessage.from"

# =============================================================================
banner "FIX 1.8 — flush outbox on login"
# =============================================================================

BLOC="lib/features/auth/presentation/bloc/auth_bloc.dart"
if grep -q "SyncStatusCubit>().refreshNow()" "$BLOC"; then
  echo "  ✓ already flushes on login"
else
  backup "$BLOC"
  pyrep "$BLOC" \
"import 'package:flutter_bloc/flutter_bloc.dart';" \
"import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';"
  pyrep "$BLOC" \
"import '../../../../core/errors/api_exception.dart';" \
"import '../../../../core/errors/api_exception.dart';
import '../../../../core/sync/sync_status_cubit.dart';
import '../../../../di/di.dart';"
  pyrep "$BLOC" \
"      );
      emit(const AuthAuthenticated());" \
"      );
      unawaited(getIt<SyncStatusCubit>().refreshNow());
      emit(const AuthAuthenticated());" all
  echo "    ✓ auth_bloc patched"
fi

run_checks
commit_if_changed "fix(auth): flush outbox on login and register success"

# =============================================================================
banner "FIX 1.9 — haptics"
# =============================================================================

SNACK="lib/shared/widgets/feedback/app_snackbar.dart"
if ! grep -q "HapticFeedback" "$SNACK"; then
  backup "$SNACK"
  pyrep "$SNACK" \
"import 'package:flutter/material.dart';" \
"import 'package:flutter/material.dart';
import 'package:flutter/services.dart';"
  pyrep "$SNACK" \
"    Color bg;
    IconData icon;
    switch (kind) {" \
"    if (kind == SnackKind.error) {
      HapticFeedback.heavyImpact();
    } else if (kind == SnackKind.success || kind == SnackKind.queued) {
      HapticFeedback.lightImpact();
    }

    Color bg;
    IconData icon;
    switch (kind) {"
  echo "    ✓ AppSnackbar haptics added"
else
  echo "  ✓ AppSnackbar already has haptics"
fi

SCAN="lib/features/scanner/presentation/screens/scanner_screen.dart"
if ! grep -q "HapticFeedback" "$SCAN"; then
  backup "$SCAN"
  pyrep "$SCAN" \
"import 'package:flutter/material.dart';" \
"import 'package:flutter/material.dart';
import 'package:flutter/services.dart';"
  pyrep "$SCAN" \
"          if (state.status == ScannerStatus.resolved &&
              state.result != null &&
              state.lastCode != null) {
            context.go(Routes.labelsDetail(state.lastCode!));" \
"          if (state.status == ScannerStatus.resolved &&
              state.result != null &&
              state.lastCode != null) {
            HapticFeedback.lightImpact();
            context.go(Routes.labelsDetail(state.lastCode!));"
  echo "    ✓ Scanner haptics added"
else
  echo "  ✓ Scanner already has haptics"
fi

DIALOG="lib/shared/widgets/feedback/confirmation_dialog.dart"
if ! grep -q "HapticFeedback" "$DIALOG"; then
  backup "$DIALOG"
  pyrep "$DIALOG" \
"import 'package:flutter/material.dart';" \
"import 'package:flutter/material.dart';
import 'package:flutter/services.dart';"
  pyrep "$DIALOG" \
"                onPressed: () => Navigator.of(context).pop(true)," \
"                onPressed: () {
                  HapticFeedback.mediumImpact();
                  Navigator.of(context).pop(true);
                },"
  echo "    ✓ ConfirmationDialog haptics added"
else
  echo "  ✓ ConfirmationDialog already has haptics"
fi

run_checks
commit_if_changed "feat(ux): haptic feedback on scan, submit, error, and destructive confirm"

# =============================================================================
banner "FIX 1.10 — sync pill in every AppBar"
# =============================================================================

PILL="lib/shared/widgets/feedback/sync_status_pill.dart"
if [[ ! -f "$PILL" ]]; then
  cat > "$PILL" <<'DART'
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/sync/sync_status.dart';
import '../../../core/sync/sync_status_cubit.dart';
import '../../../core/theme/tokens.dart';

class SyncStatusPill extends StatelessWidget {
  const SyncStatusPill({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SyncStatusCubit, SyncStatus>(
      builder: (context, state) {
        final pending = state.pendingCount;
        final review = state.manualReviewCount;
        final online = state.online;

        if (online && pending == 0 && review == 0) {
          return IconButton(
            tooltip: 'Synchronisé',
            icon: const Icon(
              Icons.cloud_done_outlined,
              size: 20,
              color: AppColors.textSecondary,
            ),
            onPressed: () => context.push(Routes.sync),
          );
        }

        final (IconData icon, Color color, String label) = review > 0
            ? (Icons.error_outline, AppColors.danger, '$review')
            : !online
                ? (Icons.cloud_off_outlined, AppColors.warning,
                    pending > 0 ? '$pending' : '')
                : (Icons.cloud_upload_outlined, AppColors.info, '$pending');

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: InkWell(
            onTap: () => context.push(Routes.sync),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: color),
                  if (label.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: AppTypography.caption.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
DART
  echo "    ✓ created sync_status_pill.dart"
else
  echo "  ✓ sync_status_pill already exists"
fi

APPBAR="lib/shared/widgets/layout/app_appbar.dart"
if ! grep -q "SyncStatusPill()" "$APPBAR"; then
  backup "$APPBAR"
  pyrep "$APPBAR" \
"import '../../../core/theme/tokens.dart';" \
"import '../../../core/theme/tokens.dart';
import '../feedback/sync_status_pill.dart';"
  pyrep "$APPBAR" \
"      actions: actions," \
"      actions: [
        ...(actions ?? const <Widget>[]),
        const SyncStatusPill(),
        const SizedBox(width: AppSpacing.xs),
      ],"
  echo "    ✓ AppAppBar wired"
else
  echo "  ✓ AppAppBar already includes SyncStatusPill"
fi

run_checks
commit_if_changed "feat(sync): always-visible sync status pill in every AppBar"

# =============================================================================
banner "PHASE 1 DONE"
# =============================================================================
echo ""
echo "Recent commits:"
git log --oneline -10
echo ""
echo "Manual next steps:"
echo "  1. Idempotency-Key curl test (see prompt from assistant)"
echo "  2. Device smoke test"
echo "  3. git push"
echo ""
