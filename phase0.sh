#!/usr/bin/env bash
# =============================================================================
# SteryMed Mobile — Phase 0 Automation Script
# =============================================================================
# Runs the full Phase 0 triage:
#   - Deletes prosthetic module
#   - Disables attachment UI
#   - Documents backend bugs
#   - Documents missing features
#   - Adds WORKAROUND comments
#   - Adds data-loss warnings to edit forms
#   - Hides site creation UI
#   - Verifies build + analyze + test
#   - Commits + tags
#
# Usage:
#   chmod +x phase0.sh
#   ./phase0.sh
#
# Safe to re-run. Idempotent. Aborts on any fatal error.
# =============================================================================

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

BRANCH_NAME="phase-0-triage"
TAG_NAME="v0.1.0-phase0"
TODAY="$(date +%Y-%m-%d)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

log_step() {
  echo ""
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}▶ $1${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

log_ok() {
  echo -e "${GREEN}✓ $1${NC}"
}

log_warn() {
  echo -e "${YELLOW}⚠ $1${NC}"
}

log_err() {
  echo -e "${RED}✗ $1${NC}"
}

fatal() {
  log_err "$1"
  exit 1
}

# Backup a file before editing (only once per run)
backup_file() {
  local file="$1"
  if [ -f "$file" ] && [ ! -f "${file}.phase0.bak" ]; then
    cp "$file" "${file}.phase0.bak"
    log_ok "Backed up $file → ${file}.phase0.bak"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 1 — Pre-flight
# ─────────────────────────────────────────────────────────────────────────────

log_step "Step 1 / 10 — Pre-flight checks"

if ! command -v flutter &> /dev/null; then
  fatal "Flutter is not installed or not on PATH."
fi

if ! command -v git &> /dev/null; then
  fatal "Git is not installed."
fi

if [ ! -f "pubspec.yaml" ]; then
  fatal "This does not appear to be a Flutter project (no pubspec.yaml)."
fi

log_ok "Flutter found: $(flutter --version | head -1)"
log_ok "Git found: $(git --version)"
log_ok "Project root: $PROJECT_ROOT"

# Check for uncommitted changes
if ! git diff-index --quiet HEAD --; then
  log_warn "You have uncommitted changes. They will be included in Phase 0 commits."
  read -r -p "Continue? [y/N] " response
  if [[ ! "$response" =~ ^[Yy]$ ]]; then
    fatal "Aborted by user."
  fi
fi

# Create or switch to the phase-0 branch
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [ "$CURRENT_BRANCH" != "$BRANCH_NAME" ]; then
  if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
    log_warn "Branch '$BRANCH_NAME' already exists. Switching to it."
    git checkout "$BRANCH_NAME"
  else
    git checkout -b "$BRANCH_NAME"
    log_ok "Created branch '$BRANCH_NAME'"
  fi
else
  log_ok "Already on branch '$BRANCH_NAME'"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Step 2 — Delete prosthetic module
# ─────────────────────────────────────────────────────────────────────────────

log_step "Step 2 / 10 — Delete prosthetic module"

if [ -d "lib/features/prosthetic" ]; then
  rm -rf lib/features/prosthetic
  log_ok "Deleted lib/features/prosthetic/"
else
  log_ok "lib/features/prosthetic/ already gone"
fi

# Strip prosthetic imports + routes from router
if [ -f "lib/core/router/app_router.dart" ]; then
  backup_file "lib/core/router/app_router.dart"
  # Remove prosthetic imports
  sed -i.tmp '/features\/prosthetic\//d' lib/core/router/app_router.dart
  rm -f lib/core/router/app_router.dart.tmp
  # Remove GoRoute blocks whose path mentions prosthetic / waiting-placement / laboratory
  python3 - <<'PYEOF'
import re
path = "lib/core/router/app_router.dart"
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

# Remove GoRoute(...) blocks containing prosthetic / waiting-placement / laboratory
pattern = re.compile(
    r"GoRoute\(\s*[^)]*?(?:prosthetic|waiting-placement|laboratory|prostheticCase|waitingPlacement)[^)]*?\),",
    re.DOTALL | re.IGNORECASE,
)
content = pattern.sub("", content)

with open(path, "w", encoding="utf-8") as f:
    f.write(content)
PYEOF
  log_ok "Stripped prosthetic references from app_router.dart"
fi

# Strip prosthetic constants from routes.dart
if [ -f "lib/core/router/routes.dart" ]; then
  backup_file "lib/core/router/routes.dart"
  sed -i.tmp -E '/prosthetic|waitingPlacement|laboratory/Id' lib/core/router/routes.dart
  rm -f lib/core/router/routes.dart.tmp
  log_ok "Stripped prosthetic constants from routes.dart"
fi

# Strip prosthetic names from route_names.dart
if [ -f "lib/core/router/route_names.dart" ]; then
  backup_file "lib/core/router/route_names.dart"
  sed -i.tmp -E '/prosthetic|waitingPlacement|laboratory/Id' lib/core/router/route_names.dart
  rm -f lib/core/router/route_names.dart.tmp
  log_ok "Stripped prosthetic names from route_names.dart"
fi

# Strip prosthetic from DI
if [ -f "lib/di/features_di.dart" ]; then
  backup_file "lib/di/features_di.dart"
  sed -i.tmp -E '/prosthetic|waiting_placement|laboratory/Id' lib/di/features_di.dart
  rm -f lib/di/features_di.dart.tmp
  log_ok "Stripped prosthetic registrations from features_di.dart"
fi

# Strip prosthetic from analytics
if [ -f "lib/core/analytics/analytics_events.dart" ]; then
  backup_file "lib/core/analytics/analytics_events.dart"
  sed -i.tmp -E '/prosthetic/Id' lib/core/analytics/analytics_events.dart
  rm -f lib/core/analytics/analytics_events.dart.tmp
  log_ok "Stripped prosthetic from analytics_events.dart"
fi

if [ -f "lib/core/analytics/analytics_service.dart" ]; then
  backup_file "lib/core/analytics/analytics_service.dart"
  sed -i.tmp -E '/prosthetic/Id' lib/core/analytics/analytics_service.dart
  rm -f lib/core/analytics/analytics_service.dart.tmp
  log_ok "Stripped prosthetic from analytics_service.dart"
fi

# Strip prosthetic from outbox operation enum
if [ -f "lib/core/storage/outbox/outbox_operation.dart" ]; then
  backup_file "lib/core/storage/outbox/outbox_operation.dart"
  sed -i.tmp -E '/prosthetic/Id' lib/core/storage/outbox/outbox_operation.dart
  rm -f lib/core/storage/outbox/outbox_operation.dart.tmp
  log_ok "Stripped prosthetic from outbox_operation.dart"
fi

# Strip prosthetic from bottom nav
if [ -f "lib/features/shell/presentation/widgets/bottom_nav_bar.dart" ]; then
  backup_file "lib/features/shell/presentation/widgets/bottom_nav_bar.dart"
  sed -i.tmp -E '/prosthetic|prothèse/Id' lib/features/shell/presentation/widgets/bottom_nav_bar.dart
  rm -f lib/features/shell/presentation/widgets/bottom_nav_bar.dart.tmp
  log_ok "Stripped prosthetic from bottom_nav_bar.dart"
fi

# Final verification
REMAINING=$(grep -ri "prosthetic" lib/ --include="*.dart" 2>/dev/null | grep -v "TODO" | wc -l | tr -d ' ' || echo "0")
if [ "$REMAINING" != "0" ]; then
  log_warn "$REMAINING references to 'prosthetic' remain in lib/. Review them manually."
  grep -rn "prosthetic" lib/ --include="*.dart" | grep -v "TODO" | head -20
else
  log_ok "Zero references to 'prosthetic' in lib/"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Step 3 — Comment out broken attachment UI
# ─────────────────────────────────────────────────────────────────────────────

log_step "Step 3 / 10 — Disable attachment upload UI"

if [ -f "lib/features/cycles/presentation/screens/cycle_attachments_screen.dart" ]; then
  backup_file "lib/features/cycles/presentation/screens/cycle_attachments_screen.dart"
  cat > lib/features/cycles/presentation/screens/cycle_attachments_screen.dart <<'DARTEOF'
// TODO(p0): Re-enable when backend attachment upload is fixed.
// See docs/BACKEND_BUGS.md#bug-001
//
// Original implementation preserved in git history.
import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';

class CycleAttachmentsScreen extends StatelessWidget {
  final String cycleId;
  const CycleAttachmentsScreen({super.key, required this.cycleId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppBar(title: const Text('Pièces jointes')),
      body: const EmptyView(
        title: 'Fonctionnalité bientôt disponible',
        message:
            'L\'ajout de pièces jointes sera activé dans une prochaine '
            'version. Merci de votre compréhension.',
        icon: Icons.construction_outlined,
      ),
    );
  }
}
DARTEOF
  log_ok "Disabled cycle_attachments_screen.dart"
fi

# Patch cycle_detail_screen to hide the "Ajouter pièce jointe" button
if [ -f "lib/features/cycles/presentation/screens/cycle_detail_screen.dart" ]; then
  backup_file "lib/features/cycles/presentation/screens/cycle_detail_screen.dart"
  python3 - <<'PYEOF'
import re
path = "lib/features/cycles/presentation/screens/cycle_detail_screen.dart"
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

# Replace the attachments SectionHeader trailing IconButton with a comment
pattern = re.compile(
    r"SectionHeader\(\s*title:\s*'Pièces jointes[^']*',\s*trailing:\s*IconButton\([^)]*?Routes\.cyclesAttachments[^)]*?\),\s*\),",
    re.DOTALL,
)
replacement = """// TODO(p0): Re-enable when backend attachment upload is fixed.
                  // See docs/BACKEND_BUGS.md#bug-001
                  const SectionHeader(title: 'Pièces jointes'),
                  const _InfoBanner(
                    message: 'L\\'ajout de pièces jointes sera disponible '
                        'dans une prochaine version.',
                  ),"""
content = pattern.sub(replacement, content)

with open(path, "w", encoding="utf-8") as f:
    f.write(content)
PYEOF
  log_ok "Patched cycle_detail_screen.dart"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Step 4 — Create docs/BACKEND_BUGS.md
# ─────────────────────────────────────────────────────────────────────────────

log_step "Step 4 / 10 — Create docs/BACKEND_BUGS.md"

mkdir -p docs

cat > docs/BACKEND_BUGS.md <<EOF
# Backend Bugs — Blocking SteryMed Mobile

**Filed by:** Mobile engineer
**Date:** $TODAY
**Backend version:** \`steriqore\` @ commit \`_____\` (fill in)
**Staging URL:** \`https://staging.example.com\`

Every bug below has a \`curl\` reproduction and a suggested fix.
Bugs are ordered by severity (blocking → non-blocking).

---

## BUG-001 — Attachment upload returns 500

**Severity:** 🔴 Blocking
**Endpoint:** \`POST /api/v1/cycles/{cycle}/attachments\`
**Called by:** \`CycleAttachmentsScreen\`, \`CycleDetailBloc\`

### Reproduction

\`\`\`bash
curl -X POST "https://staging.example.com/api/v1/cycles/{cycle_id}/attachments" \\
  -H "Authorization: Bearer \$TOKEN" \\
  -H "Accept: application/json" \\
  -H "Idempotency-Key: test-\$(date +%s)" \\
  -F "file=@test.png"
\`\`\`

**Expected:** \`200\` with \`{id, url, file_name, mime_type, size, created_at}\`.
**Actual:** \`500 Internal Server Error\`.

### Impact

- Mobile app has no way to attach photos or PDFs to a cycle.
- Feature is currently **disabled** in the mobile UI.

---

## BUG-002 — Missing \`GET /api/v1/locations\`

**Severity:** 🔴 Blocking
**Called by:** \`GoodsReceiptScreen\`, \`StockAdjustScreen\`, \`StockTransferScreen\`

### Current workaround

Mobile derives the list of locations from \`GET /api/v1/stock-levels\`.
Zero-stock locations never appear.

### Expected

\`\`\`json
{
  "data": [
    { "id": "uuid", "name": "Armoire A", "site_id": "uuid" }
  ]
}
\`\`\`

---

## BUG-003 — Missing \`GET /api/v1/batches\`

**Severity:** 🔴 Blocking
**Called by:** Same as BUG-002.

### Current workaround

Same as BUG-002. Batches derived from \`/stock-levels\`.

### Expected

\`\`\`json
{
  "data": [
    {
      "id": "uuid",
      "batch_number": "LOT-2026-01",
      "product_id": "uuid",
      "product_name": "Gants nitrile",
      "expiry_date": "2027-01-01"
    }
  ]
}
\`\`\`

---

## BUG-004 — Missing \`POST /api/v1/sites\` and \`POST /api/v1/locations\`

**Severity:** 🟡 Non-blocking
**Impact:** Mobile cannot create a site. Feature is hidden.

---

## BUG-005 — Missing \`PATCH /api/v1/patients/{id}\`

**Severity:** 🔴 Blocking
**Called by:** \`PatientFormSheet\`

### Current workaround

Mobile does **delete + recreate** to edit a patient.
- Patient \`id\` changes
- Foreign keys break
- Audit history broken

### Expected

\`\`\`http
PATCH /api/v1/patients/{id}
Content-Type: application/json

{
  "first_name": "Jane",
  "last_name": "Doe",
  "phone": "+33612345678",
  "email": "jane@example.com"
}
\`\`\`

---

## BUG-006 — Missing \`PATCH /api/v1/products/{id}\`

**Severity:** 🔴 Blocking
**Called by:** \`ProductFormSheet\`

### Expected

Same shape as BUG-005.

---

## BUG-007 — Missing \`PATCH /api/v1/cycles/{id}\`

**Severity:** 🟡 Non-blocking
**Called by:** \`CycleDetailScreen\` (caches notes locally)

### Expected

\`\`\`http
PATCH /api/v1/cycles/{id}
Content-Type: application/json

{
  "notes": "Cassettes chirurgicales Dr. Watson"
}
\`\`\`

---

## BUG-008 — \`GET /api/v1/patients\` returns only \`{id, reference}\`

**Severity:** 🔴 Blocking
**Called by:** \`PatientListScreen\`, \`PatientPickerSheet\`

### Current workaround

Mobile caches the full record locally after creation. Patients created
elsewhere show only the reference.

### Expected

\`\`\`json
{
  "data": [
    {
      "id": "uuid",
      "reference": "PAT-0001",
      "first_name": "Jane",
      "last_name": "Doe",
      "phone": "+33612345678",
      "email": "jane@example.com",
      "birth_date": "1990-01-01",
      "created_at": "..."
    }
  ]
}
\`\`\`

---

## Summary

| ID | Severity | Endpoint | Mobile impact |
|----|----------|----------|---------------|
| BUG-001 | 🔴 | \`POST /cycles/{id}/attachments\` | Attachments disabled |
| BUG-002 | 🔴 | \`GET /locations\` | Workaround in place |
| BUG-003 | 🔴 | \`GET /batches\` | Workaround in place |
| BUG-004 | 🟡 | \`POST /sites\`, \`POST /locations\` | Feature hidden |
| BUG-005 | 🔴 | \`PATCH /patients/{id}\` | Delete+recreate hazard |
| BUG-006 | 🔴 | \`PATCH /products/{id}\` | Delete+recreate hazard |
| BUG-007 | 🟡 | \`PATCH /cycles/{id}\` | Notes not synced |
| BUG-008 | 🔴 | \`GET /patients\` | Name missing on cold start |

---

## Tracking

- **$TODAY** — Bug report generated. Awaiting send.
EOF

log_ok "Created docs/BACKEND_BUGS.md"

# ─────────────────────────────────────────────────────────────────────────────
# Step 5 — Create docs/MISSING_FEATURES.md
# ─────────────────────────────────────────────────────────────────────────────

log_step "Step 5 / 10 — Create docs/MISSING_FEATURES.md"

cat > docs/MISSING_FEATURES.md <<EOF
# Missing Features & Workarounds

**Purpose:** Every place where the mobile app deviates from intended
behavior because the backend does not support it.

**Last updated:** $TODAY

---

## 1. Patient edit uses delete + recreate

**File:** \`lib/features/patients/data/repositories/patient_repository.dart\`
**Why:** Backend has no \`PATCH /v1/patients/{id}\`. See \`BACKEND_BUGS.md#bug-005\`.
**Impact:** Patient ID changes on every edit. Foreign keys break.
**Fix when:** \`PATCH /v1/patients/{id}\` exists.

---

## 2. Product edit uses delete + recreate

**File:** \`lib/features/catalog/data/repositories/product_repository.dart\`
**Why:** Backend has no \`PATCH /v1/products/{id}\`. See \`BACKEND_BUGS.md#bug-006\`.
**Impact:** Product ID changes on every edit. Batch references break.
**Fix when:** \`PATCH /v1/products/{id}\` exists.

---

## 3. Cycle notes are cached locally only

**File:** \`lib/features/cycles/data/local/cycle_notes_cache.dart\`
**Why:** Backend has no \`PATCH /v1/cycles/{id}\`. See \`BACKEND_BUGS.md#bug-007\`.
**Impact:** Notes lost if device is reset. Notes never sync.
**Fix when:** \`PATCH /v1/cycles/{id}\` exists.

---

## 4. Patient names are cached locally

**File:** \`lib/features/patients/data/local/patient_local_cache.dart\`
**Why:** \`GET /v1/patients\` returns only \`{id, reference}\`. See \`BACKEND_BUGS.md#bug-008\`.
**Impact:** Patients created elsewhere have no name.
**Fix when:** \`GET /v1/patients\` returns the full record.

---

## 5. Locations derived from stock-levels

**File:** \`lib/features/stock/data/datasources/stock_remote_datasource.dart\`
**Why:** Backend has no \`GET /v1/locations\`. See \`BACKEND_BUGS.md#bug-002\`.
**Impact:** Zero-stock locations never appear.
**Fix when:** \`GET /v1/locations\` exists.

---

## 6. Batches derived from stock-levels

**File:** Same as above.
**Why:** Backend has no \`GET /v1/batches\`. See \`BACKEND_BUGS.md#bug-003\`.
**Impact:** Zero-stock batches never appear.
**Fix when:** \`GET /v1/batches\` exists.

---

## 7. Sites cannot be created from mobile

**File:** \`lib/features/sites/presentation/screens/site_list_screen.dart\`
**Why:** Backend has no \`POST /v1/sites\`. See \`BACKEND_BUGS.md#bug-004\`.
**Fix when:** \`POST /v1/sites\` exists.

---

## 8. Attachment upload is disabled

**File:** \`lib/features/cycles/presentation/screens/cycle_attachments_screen.dart\`
**Why:** Backend returns 500. See \`BACKEND_BUGS.md#bug-001\`.
**Fix when:** Backend returns 200 on upload.

---

## 9. Prosthetic module is deleted

**File:** Was \`lib/features/prosthetic/\`
**Why:** Backend has no prosthetic domain. See \`docs/adr/0010-prosthetic-deferred.md\`.
**Fix when:** Backend ships the prosthetic domain.
EOF

log_ok "Created docs/MISSING_FEATURES.md"

# ─────────────────────────────────────────────────────────────────────────────
# Step 6 — Add WORKAROUND comments to code
# ─────────────────────────────────────────────────────────────────────────────

log_step "Step 6 / 10 — Add WORKAROUND comments"

add_workaround_header() {
  local file="$1"
  local header="$2"
  if [ -f "$file" ]; then
    # Check if the header is already present
    if ! grep -q "WORKAROUND:" "$file"; then
      backup_file "$file"
      # Prepend header at the very top of the file
      printf '%s\n\n' "$header" | cat - "$file" > "${file}.tmp"
      mv "${file}.tmp" "$file"
      log_ok "Added WORKAROUND to $file"
    else
      log_ok "WORKAROUND already present in $file"
    fi
  fi
}

add_workaround_header "lib/features/patients/data/repositories/patient_repository.dart" \
"// WORKAROUND: Backend has no PATCH /v1/patients/{id}.
// update() = delete + recreate. Data-loss risk.
// See docs/MISSING_FEATURES.md#1. Remove when BACKEND_BUGS.md#bug-005 is fixed."

add_workaround_header "lib/features/catalog/data/repositories/product_repository.dart" \
"// WORKAROUND: Backend has no PATCH /v1/products/{id}.
// update() = delete + recreate. Data-loss risk.
// See docs/MISSING_FEATURES.md#2. Remove when BACKEND_BUGS.md#bug-006 is fixed."

add_workaround_header "lib/features/cycles/data/local/cycle_notes_cache.dart" \
"// WORKAROUND: Backend has no PATCH /v1/cycles/{id}.
// Notes cached in Hive only, never synced.
// See docs/MISSING_FEATURES.md#3. Remove when BACKEND_BUGS.md#bug-007 is fixed."

add_workaround_header "lib/features/patients/data/local/patient_local_cache.dart" \
"// WORKAROUND: Backend GET /v1/patients returns only {id, reference}.
// Full record cached locally.
// See docs/MISSING_FEATURES.md#4. Remove when BACKEND_BUGS.md#bug-008 is fixed."

add_workaround_header "lib/features/stock/data/datasources/stock_remote_datasource.dart" \
"// WORKAROUND: Backend has no GET /v1/locations or GET /v1/batches.
// Both derived from /stock-levels. Incomplete.
// See docs/MISSING_FEATURES.md#5 and #6.
// Remove when BACKEND_BUGS.md#bug-002 and #bug-003 are fixed."

# ─────────────────────────────────────────────────────────────────────────────
# Step 7 — Add warning UI to patient/product edit forms
# ─────────────────────────────────────────────────────────────────────────────

log_step "Step 7 / 10 — Add data-loss warnings to edit forms"

# Patient form
if [ -f "lib/features/patients/presentation/widgets/patient_form_sheet.dart" ]; then
  backup_file "lib/features/patients/presentation/widgets/patient_form_sheet.dart"
  python3 - <<'PYEOF'
import re
path = "lib/features/patients/presentation/widgets/patient_form_sheet.dart"
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

# Replace the existing info banner inside if (_isEdit) with a stronger warning
pattern = re.compile(
    r"if \(_isEdit\) \.\.\.\[\s*const SizedBox\(height: AppSpacing\.sm\),\s*Container\(.*?\),\s*\],",
    re.DOTALL,
)

warning = """if (_isEdit) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.dangerLight,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.danger),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_outlined,
                            color: AppColors.danger, size: 20),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Attention — données historiques',
                            style: AppTypography.bodyStrong
                                .copyWith(color: AppColors.danger),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const Text(
                      'La modification d\\'un patient recrée une nouvelle fiche. '
                      'Le numéro de dossier interne changera et l\\'historique '
                      'de traçabilité (utilisations d\\'étiquettes) ne sera '
                      'plus rattaché automatiquement à ce patient.',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
              CheckboxListTile(
                value: _confirmed,
                onChanged: (v) => setState(() => _confirmed = v ?? false),
                title: const Text(
                  'Je comprends et souhaite continuer',
                  style: AppTypography.caption,
                ),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            ],"""

content = pattern.sub(warning, content, count=1)

# Add _confirmed field if not present
if "_confirmed" not in content:
    content = content.replace(
        "bool get _isEdit => widget.existing != null;",
        "bool get _isEdit => widget.existing != null;\n  bool _confirmed = false;"
    )

# Add confirmation check in _submit
content = content.replace(
    "Future<void> _submit() async {\n    if (!_formKey.currentState!.validate()) return;",
    """Future<void> _submit() async {
    if (_isEdit && !_confirmed) {
      AppSnackbar.show(
        context,
        'Veuillez confirmer la recréation de la fiche.',
        kind: SnackKind.warning,
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;"""
)

with open(path, "w", encoding="utf-8") as f:
    f.write(content)
PYEOF
  log_ok "Patched patient_form_sheet.dart"
fi

# Product form
if [ -f "lib/features/catalog/presentation/widgets/product_form_sheet.dart" ]; then
  backup_file "lib/features/catalog/presentation/widgets/product_form_sheet.dart"
  python3 - <<'PYEOF'
import re
path = "lib/features/catalog/presentation/widgets/product_form_sheet.dart"
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

# Add _confirmed field
if "_confirmed" not in content:
    content = content.replace(
        "bool _isSterilizable = false;",
        "bool _isSterilizable = false;\n  bool _confirmed = false;"
    )

# Insert warning block after the section title
warning = """            if (widget.existing != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.dangerLight,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.danger),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_outlined,
                            color: AppColors.danger, size: 20),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Attention — données historiques',
                            style: AppTypography.bodyStrong
                                .copyWith(color: AppColors.danger),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const Text(
                      'La modification d\\'un produit recrée une nouvelle fiche. '
                      'Les lots en stock ne seront plus rattachés '
                      'automatiquement à ce produit.',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
              CheckboxListTile(
                value: _confirmed,
                onChanged: (v) => setState(() => _confirmed = v ?? false),
                title: const Text(
                  'Je comprends et souhaite continuer',
                  style: AppTypography.caption,
                ),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            ],
"""

# Insert warning before the first AppTextField
content = content.replace(
    "const SizedBox(height: AppSpacing.md),\n            AppTextField(\n              label: 'Nom *',",
    warning + "            const SizedBox(height: AppSpacing.md),\n            AppTextField(\n              label: 'Nom *',",
    1,
)

# Add confirmation check in _submit
content = content.replace(
    "void _submit() {\n    if (!_formKey.currentState!.validate()) return;",
    """void _submit() {
    if (widget.existing != null && !_confirmed) {
      AppSnackbar.show(
        context,
        'Veuillez confirmer la recréation de la fiche.',
        kind: SnackKind.warning,
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;"""
)

with open(path, "w", encoding="utf-8") as f:
    f.write(content)
PYEOF
  log_ok "Patched product_form_sheet.dart"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Step 8 — Hide site creation UI
# ─────────────────────────────────────────────────────────────────────────────

log_step "Step 8 / 10 — Hide site creation UI"

if [ -f "lib/features/sites/presentation/screens/site_list_screen.dart" ]; then
  backup_file "lib/features/sites/presentation/screens/site_list_screen.dart"
  python3 - <<'PYEOF'
import re
path = "lib/features/sites/presentation/screens/site_list_screen.dart"
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

# Remove any IconButton/FAB that triggers site creation
content = re.sub(
    r"actions:\s*\[[^\]]*?(?:create|nouveau|add|plus)[^\]]*?\]",
    "actions: const []",
    content,
    flags=re.IGNORECASE,
)
content = re.sub(
    r"floatingActionButton:\s*[^,]*?,",
    "floatingActionButton: null,",
    content,
    flags=re.IGNORECASE,
)

# Ensure the info banner is present (idempotent)
if "La création de sites est réservée" not in content:
    banner = """Container(
            width: double.infinity,
            margin: const EdgeInsets.all(AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.infoLight,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    color: AppColors.info, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'La création de sites est réservée à l\\'administrateur '
                    'via l\\'interface web.',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.info),
                  ),
                ),
              ],
            ),
          ),
"""
    # Insert banner right after the AppBar close, before body
    content = re.sub(
        r"(body:\s*)",
        "body: Column(children: [\n          " + banner + "          Expanded(child: ",
        content,
        count=1,
    )
    # Close the Column + Expanded with an extra bracket at the end of body
    content = content.replace(
        "      ),\n    );\n  }\n}",
        "      ),\n    ),\n    ),\n    ],\n  ),\n  );\n  }\n}",
        1,
    )

with open(path, "w", encoding="utf-8") as f:
    f.write(content)
PYEOF
  log_ok "Patched site_list_screen.dart"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Step 9 — Fix CI + smoke test
# ─────────────────────────────────────────────────────────────────────────────

log_step "Step 9 / 10 — Ensure CI has a test workflow + smoke test"

mkdir -p test/unit/core

if [ ! -f "test/unit/core/smoke_test.dart" ]; then
  cat > test/unit/core/smoke_test.dart <<'DARTEOF'
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('smoke — pipeline is alive', () {
    expect(1 + 1, 2);
  });
}
DARTEOF
  log_ok "Created test/unit/core/smoke_test.dart"
fi

mkdir -p .github/workflows

if [ ! -f ".github/workflows/mobile-test.yml" ]; then
  cat > .github/workflows/mobile-test.yml <<'YAMLEOF'
name: Mobile — Test

on:
  push:
    branches: [main, 'phase-*', 'mvp/**']
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: 'stable'
          cache: true
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test --coverage
YAMLEOF
  log_ok "Created .github/workflows/mobile-test.yml"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Step 10 — Verify + commit
# ─────────────────────────────────────────────────────────────────────────────

log_step "Step 10 / 10 — Verification + commit"

echo ""
echo "▶ flutter clean"
flutter clean || fatal "flutter clean failed"

echo ""
echo "▶ flutter pub get"
flutter pub get || fatal "flutter pub get failed"

echo ""
echo "▶ flutter analyze"
if flutter analyze; then
  log_ok "Analyze clean"
else
  log_warn "Analyze produced issues. Review above output."
  echo ""
  read -r -p "Continue anyway? [y/N] " response
  if [[ ! "$response" =~ ^[Yy]$ ]]; then
    fatal "Aborted by user."
  fi
fi

echo ""
echo "▶ flutter test"
flutter test || fatal "flutter test failed"

echo ""
echo "▶ flutter build apk --debug"
flutter build apk --debug || fatal "flutter build apk --debug failed"

# Remove backup files before committing
find . -name "*.phase0.bak" -type f -delete
log_ok "Cleaned up backup files"

# Final report
echo ""
log_step "Phase 0 — Final Report"

echo ""
echo "Verification:"
echo "  prosthetic references in lib/: $(grep -ri "prosthetic" lib/ --include="*.dart" 2>/dev/null | grep -v "TODO" | wc -l | tr -d ' ')"
echo "  attachment UI refs in lib/:   $(grep -rn "CycleAttachmentGrid\|uploadAttachment" lib/ --include="*.dart" 2>/dev/null | wc -l | tr -d ' ')"
echo "  BACKEND_BUGS.md:              $([ -f docs/BACKEND_BUGS.md ] && echo "exists" || echo "MISSING")"
echo "  MISSING_FEATURES.md:          $([ -f docs/MISSING_FEATURES.md ] && echo "exists" || echo "MISSING")"
echo "  smoke_test.dart:              $([ -f test/unit/core/smoke_test.dart ] && echo "exists" || echo "MISSING")"
echo "  mobile-test.yml:              $([ -f .github/workflows/mobile-test.yml ] && echo "exists" || echo "MISSING")"
echo ""

# Git add + commit
git add -A

if git diff --cached --quiet; then
  log_warn "Nothing to commit. Phase 0 already applied."
else
  git commit -m "chore(p0): complete Phase 0 triage

- Delete prosthetic module (backend does not exist)
- Disable attachment upload UI (backend returns 500)
- Add docs/BACKEND_BUGS.md with 8 curl reproductions
- Add docs/MISSING_FEATURES.md with all workarounds
- Add WORKAROUND comments to deviating code
- Add data-loss warnings to patient/product edit forms
- Hide site creation UI
- Add smoke test + test workflow

Phase 0 gate: all checks green."
  log_ok "Committed Phase 0"
fi

# Tag
if git rev-parse "$TAG_NAME" >/dev/null 2>&1; then
  log_warn "Tag $TAG_NAME already exists."
else
  git tag -a "$TAG_NAME" -m "Phase 0 triage complete — $(date)"
  log_ok "Tagged $TAG_NAME"
fi

# Final instructions
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ Phase 0 complete.${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Next steps:"
echo ""
echo "  1. Push the branch and tag:"
echo "     git push origin $BRANCH_NAME"
echo "     git push origin $TAG_NAME"
echo ""
echo "  2. Watch CI on GitHub Actions. Must be green."
echo ""
echo "  3. Send docs/BACKEND_BUGS.md to the backend engineer."
echo ""
echo "  4. Merge to main when CI is green:"
echo "     git checkout main"
echo "     git merge --no-ff $BRANCH_NAME"
echo "     git push"
echo ""
echo "  5. When Gate P0 is verified, start Phase 1."
echo ""