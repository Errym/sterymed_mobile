#!/usr/bin/env bash
# =============================================================================
# scripts/phase_0_triage.sh
#
# SteryMed Mobile — Phase 0: Triage & Bug Reports
#
# One script to execute the entire Phase 0:
#   - Delete prosthetic module
#   - Disable broken attachment UI
#   - Write BACKEND_BUGS.md
#   - Write MISSING_FEATURES.md
#   - Create/verify CI workflows
#   - Verify all gates
#   - Commit and tag
#
# Usage:
#   ./scripts/phase_0_triage.sh           # full run
#   ./scripts/phase_0_triage.sh --dry-run # show what would happen
#   ./scripts/phase_0_triage.sh --no-push # skip git push
#   ./scripts/phase_0_triage.sh --skip-ci # skip CI push (local only)
#
# Requirements:
#   - Flutter SDK 3.24.x
#   - git
#   - Run from project root
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
SCRIPT_NAME="phase_0_triage"
BRANCH_NAME="phase-0-triage"
TAG_NAME="phase-0-complete"
DRY_RUN=false
NO_PUSH=false
SKIP_CI=false
START_TIME=$(date +%s)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# -----------------------------------------------------------------------------
# Parse args
# -----------------------------------------------------------------------------
for arg in "$@"; do
  case $arg in
    --dry-run)  DRY_RUN=true ;;
    --no-push)  NO_PUSH=true ;;
    --skip-ci)  SKIP_CI=true ;;
    --help|-h)
      echo "Usage: $0 [--dry-run] [--no-push] [--skip-ci]"
      exit 0
      ;;
  esac
done

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
log_section() {
  echo ""
  echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}${BLUE}  $1${NC}"
  echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"
}

log_step() {
  echo -e "${CYAN}▶${NC} $1"
}

log_ok() {
  echo -e "${GREEN}✅${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}⚠️${NC}  $1"
}

log_err() {
  echo -e "${RED}❌${NC} $1"
}

log_info() {
  echo -e "   ${NC}$1${NC}"
}

run_cmd() {
  if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}[DRY]${NC} $*"
  else
    "$@"
  fi
}

confirm() {
  if [ "$DRY_RUN" = true ]; then
    return 0
  fi
  read -r -p "$(echo -e "${YELLOW}❓${NC} $1 [y/N] ")" response
  case "$response" in
    [yY][eE][sS]|[yY]) return 0 ;;
    *) return 1 ;;
  esac
}

abort() {
  log_err "$1"
  echo ""
  echo -e "${RED}Phase 0 ABORTED. Fix the issue and re-run.${NC}"
  exit 1
}

# -----------------------------------------------------------------------------
# Banner
# -----------------------------------------------------------------------------
clear
echo ""
echo -e "${BOLD}${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${BLUE}║                                                               ║${NC}"
echo -e "${BOLD}${BLUE}║       SteryMed Mobile — Phase 0: Triage & Bug Reports         ║${NC}"
echo -e "${BOLD}${BLUE}║                                                               ║${NC}"
echo -e "${BOLD}${BLUE}║       One script. Every step. Every gate.                     ║${NC}"
echo -e "${BOLD}${BLUE}║                                                               ║${NC}"
echo -e "${BOLD}${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ "$DRY_RUN" = true ]; then
  log_warn "DRY RUN MODE — no changes will be made"
fi

# =============================================================================
# PRE-FLIGHT
# =============================================================================
log_section "Pre-Flight Check"

# Verify we're in the project root
if [ ! -f "pubspec.yaml" ]; then
  abort "Not in project root. pubspec.yaml not found."
fi

if [ ! -d "lib" ]; then
  abort "lib/ directory not found. Are you in the Flutter project root?"
fi

log_ok "In project root: $(pwd)"

# Verify Flutter
if ! command -v flutter >/dev/null 2>&1; then
  abort "flutter command not found. Install Flutter 3.24.x."
fi

FLUTTER_VERSION=$(flutter --version --machine 2>/dev/null | grep -o '"frameworkVersion":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
log_ok "Flutter detected: $FLUTTER_VERSION"

# Verify git
if ! command -v git >/dev/null 2>&1; then
  abort "git command not found."
fi

log_ok "git detected: $(git --version)"

# Create docs dir if missing
run_cmd mkdir -p docs
run_cmd mkdir -p docs/adr
run_cmd mkdir -p .github/workflows
run_cmd mkdir -p test/unit/core

# Verify clean working tree
if [ "$DRY_RUN" = false ]; then
  if ! git diff-index --quiet HEAD --; then
    log_warn "Working tree is not clean. Uncommitted changes exist."
    echo ""
    git status --short | head -20
    echo ""
    if ! confirm "Continue anyway? (changes will be included in Phase 0 commit)"; then
      abort "User aborted."
    fi
  fi
fi

log_ok "Pre-flight complete"

# =============================================================================
# BASELINE CAPTURE
# =============================================================================
log_section "Baseline Capture"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)

run_cmd bash -c "flutter --version > docs/_phase0_flutter_version.txt 2>&1 || true"
log_ok "Captured Flutter version"

run_cmd bash -c "flutter analyze > docs/_phase0_analyze_before.txt 2>&1 || true"
log_ok "Captured analyze baseline"

run_cmd bash -c "flutter test > docs/_phase0_test_before.txt 2>&1 || true"
log_ok "Captured test baseline"

run_cmd bash -c "flutter build apk --debug > docs/_phase0_build_before.txt 2>&1 || true"
log_ok "Captured build baseline"

# =============================================================================
# T0.1 — DELETE PROSTHETIC MODULE
# =============================================================================
log_section "T0.1 — Delete Prosthetic Module"

# Audit before deletion
log_step "Auditing prosthetic references..."
PROSTHETIC_COUNT=$(grep -ri "prosthetic" lib/ test/ integration_test/ --include="*.dart" 2>/dev/null | wc -l | tr -d ' ' || echo "0")
log_info "Found $PROSTHETIC_COUNT references in Dart files"

run_cmd bash -c "grep -ri 'prosthetic' lib/ test/ integration_test/ --include='*.dart' 2>/dev/null > docs/_phase0_prosthetic_references.txt || true"

# Delete the feature folder
if [ -d "lib/features/prosthetic" ]; then
  log_step "Deleting lib/features/prosthetic/..."
  run_cmd rm -rf lib/features/prosthetic/
  log_ok "Prosthetic feature folder deleted"
else
  log_info "Prosthetic feature folder already gone"
fi

# Clean router
if [ -f "lib/core/router/app_router.dart" ]; then
  log_step "Cleaning app_router.dart..."
  if [ "$DRY_RUN" = false ]; then
    # Remove import lines
    sed -i.bak '/features\/prosthetic/d' lib/core/router/app_router.dart
    # Remove GoRoute blocks with prosthetic paths (multiline)
    python3 - <<'PYEOF'
import re
import sys

path = "lib/core/router/app_router.dart"
with open(path, "r") as f:
    content = f.read()

# Remove GoRoute blocks that mention prosthetic
# Matches: GoRoute( ... any mention of prosthetic ... ),
pattern = re.compile(
    r'GoRoute\s*\([^)]*prosthetic[^)]*\),',
    re.DOTALL | re.IGNORECASE
)
content = pattern.sub('', content)

# Remove any line that still mentions prosthetic in the file
lines = content.split('\n')
lines = [l for l in lines if 'prosthetic' not in l.lower()]
content = '\n'.join(lines)

with open(path, "w") as f:
    f.write(content)

print(f"Cleaned {path}")
PYEOF
    rm -f lib/core/router/app_router.dart.bak
  fi
  log_ok "app_router.dart cleaned"
fi

# Clean route names
if [ -f "lib/core/router/route_names.dart" ]; then
  log_step "Cleaning route_names.dart..."
  if [ "$DRY_RUN" = false ]; then
    sed -i.bak '/prosthetic/I d' lib/core/router/route_names.dart
    rm -f lib/core/router/route_names.dart.bak
  fi
  log_ok "route_names.dart cleaned"
fi

# Clean routes
if [ -f "lib/core/router/routes.dart" ]; then
  log_step "Cleaning routes.dart..."
  if [ "$DRY_RUN" = false ]; then
    sed -i.bak '/prosthetic/I d' lib/core/router/routes.dart
    rm -f lib/core/router/routes.dart.bak
  fi
  log_ok "routes.dart cleaned"
fi

# Clean guards
for f in lib/core/router/guards/auth_guard.dart lib/core/router/guards/role_guard.dart; do
  if [ -f "$f" ]; then
    if grep -qi "prosthetic" "$f"; then
      log_step "Cleaning $f..."
      if [ "$DRY_RUN" = false ]; then
        sed -i.bak '/prosthetic/I d' "$f"
        rm -f "$f.bak"
      fi
      log_ok "$f cleaned"
    fi
  fi
done

# Clean outbox_operation.dart
if [ -f "lib/core/storage/outbox/outbox_operation.dart" ]; then
  log_step "Cleaning outbox_operation.dart..."
  if [ "$DRY_RUN" = false ]; then
    python3 - <<'PYEOF'
import re

path = "lib/core/storage/outbox/outbox_operation.dart"
with open(path, "r") as f:
    content = f.read()

# Remove enum values
content = re.sub(r'\s*prostheticTransition,', '', content)
content = re.sub(r'\s*prostheticAttachment,', '', content)

# Remove case blocks
content = re.sub(
    r'\s*case OutboxOperation\.prostheticTransition:.*?(?=\s*case|\s*})',
    '',
    content,
    flags=re.DOTALL
)
content = re.sub(
    r'\s*case OutboxOperation\.prostheticAttachment:.*?(?=\s*case|\s*})',
    '',
    content,
    flags=re.DOTALL
)

# Remove any remaining prosthetic lines
lines = content.split('\n')
lines = [l for l in lines if 'prosthetic' not in l.lower()]
content = '\n'.join(lines)

with open(path, "w") as f:
    f.write(content)
print(f"Cleaned {path}")
PYEOF
  fi
  log_ok "outbox_operation.dart cleaned"
fi

# Clean analytics
for f in lib/core/analytics/analytics_events.dart lib/core/analytics/analytics_service.dart; do
  if [ -f "$f" ]; then
    if grep -qi "prosthetic" "$f"; then
      log_step "Cleaning $f..."
      if [ "$DRY_RUN" = false ]; then
        sed -i.bak '/prosthetic/I d' "$f"
        rm -f "$f.bak"
      fi
      log_ok "$f cleaned"
    fi
  fi
done

# Clean DI
if [ -f "lib/di/features_di.dart" ]; then
  log_step "Cleaning features_di.dart..."
  if [ "$DRY_RUN" = false ]; then
    python3 - <<'PYEOF'
import re

path = "lib/di/features_di.dart"
with open(path, "r") as f:
    content = f.read()

# Remove imports
content = re.sub(r"import '.*prosthetic.*';\n", '', content, flags=re.IGNORECASE)

# Remove registration blocks (multiline, up to matching });
pattern = re.compile(
    r'getIt\.register\w+<\s*Prosthetic[^>]*>\s*\([^;]*?\);',
    re.DOTALL
)
content = pattern.sub('', content)

# Remove remaining prosthetic lines
lines = content.split('\n')
lines = [l for l in lines if 'prosthetic' not in l.lower()]
content = '\n'.join(lines)

with open(path, "w") as f:
    f.write(content)
print(f"Cleaned {path}")
PYEOF
  fi
  log_ok "features_di.dart cleaned"
fi

# Delete prosthetic test files
log_step "Deleting prosthetic test files..."
PROSTHETIC_TESTS=(
  "test/unit/features/prosthetic/prosthetic_status_transition_test.dart"
  "test/unit/features/prosthetic/remaining_balance_test.dart"
  "test/unit/features/prosthetic/waiting_placement_filter_test.dart"
  "test/bloc/prosthetic_case_detail_bloc_test.dart"
  "test/bloc/prosthetic_list_bloc_test.dart"
  "test/bloc/prosthetic_payment_bloc_test.dart"
  "test/bloc/prosthetic_status_bloc_test.dart"
  "test/bloc/waiting_placement_bloc_test.dart"
  "test/widget/prosthetic_case_detail_test.dart"
  "test/widget/prosthetic_form_test.dart"
  "test/widget/waiting_placement_screen_test.dart"
  "test/fixtures/prosthetic_case_fixture.dart"
  "test/fixtures/payment_fixture.dart"
  "test/fixtures/laboratory_fixture.dart"
  "test/fixtures/waiting_placement_fixture.dart"
  "test/golden/prosthetic_case_detail_golden_test.dart"
  "integration_test/journeys/prosthetic_case_journey_test.dart"
  "integration_test/journeys/waiting_placement_journey_test.dart"
)
for f in "${PROSTHETIC_TESTS[@]}"; do
  if [ -f "$f" ]; then
    run_cmd rm -f "$f"
  fi
done
log_ok "Prosthetic test files deleted"

# Remove empty dirs
run_cmd bash -c "rmdir test/unit/features/prosthetic 2>/dev/null || true"
run_cmd bash -c "rmdir test/unit/features 2>/dev/null || true"

# Delete prosthetic doc
run_cmd rm -f docs/PROSTHETIC_MODULE.md

# Supersede ADR 0010
if [ -f "docs/adr/0010-prosthetic-deferred.md" ]; then
  log_step "Superseding ADR 0010..."
  if [ "$DRY_RUN" = false ]; then
    python3 - <<'PYEOF'
from datetime import date

path = "docs/adr/0010-prosthetic-deferred.md"
with open(path, "r") as f:
    content = f.read()

marker = "---\n**Superseded:**"
if marker not in content:
    prefix = (
        "---\n"
        f"**Superseded:** {date.today().isoformat()} — Module deleted from "
        "codebase in Phase 0 triage. See `docs/DAILY_LOG.md` for the "
        "deletion record.\n"
        "---\n\n"
    )
    content = prefix + content
    with open(path, "w") as f:
        f.write(content)
    print("ADR 0010 superseded")
else:
    print("ADR 0010 already superseded")
PYEOF
  fi
fi

# Verify deletion
REMAINING=$(grep -ri "prosthetic" lib/ test/ integration_test/ --include="*.dart" 2>/dev/null | wc -l | tr -d ' ' || echo "0")
if [ "$REMAINING" -gt 0 ] && [ "$DRY_RUN" = false ]; then
  log_warn "$REMAINING prosthetic references still in Dart files:"
  grep -ri "prosthetic" lib/ test/ integration_test/ --include="*.dart" | head -10
  log_warn "Manual cleanup may be needed. Continuing..."
else
  log_ok "Zero prosthetic references in Dart code"
fi

# =============================================================================
# T0.2 — DISABLE BROKEN ATTACHMENT UI
# =============================================================================
log_section "T0.2 — Disable Broken Attachment UI"

# Fix cycle_detail_screen.dart
CYCLE_DETAIL="lib/features/cycles/presentation/screens/cycle_detail_screen.dart"
if [ -f "$CYCLE_DETAIL" ]; then
  log_step "Disabling attachment section in cycle_detail_screen.dart..."
  if [ "$DRY_RUN" = false ]; then
    python3 - <<'PYEOF'
import re

path = "lib/features/cycles/presentation/screens/cycle_detail_screen.dart"
with open(path, "r") as f:
    content = f.read()

# Check if already disabled
if "Deferred to v1.1" in content and "backend returns 500" in content:
    print("Already disabled — skipping")
else:
    # Find the attachments section block
    # Match from "── Attachments ──" through the end of that block
    pattern = re.compile(
        r'(// ── Attachments ──.*?)(?=\n\s*// ──|\n\s*if \(state\.release|\n\s*// ── Action button|\n\s*const SizedBox\(height: AppSpacing\.xxl\))',
        re.DOTALL
    )
    
    replacement = '''// ── Attachments ──
// TODO: Re-enable when backend attachment upload is fixed (see docs/BACKEND_BUGS.md#attachment-upload)
// Status: Deferred to v1.1 — backend returns 500 on POST /v1/cycles/{id}/attachments
const SizedBox(height: AppSpacing.lg),
SectionHeader(title: 'Pièces jointes'),
const _InfoBanner(
  message: 'L\\'ajout de pièces jointes sera disponible dans une '
      'prochaine version.',
),
'''
    
    new_content = pattern.sub(replacement, content)
    
    # If no match, append a note
    if new_content == content:
        print("Warning: attachments section not found by pattern — manual review needed")
    else:
        with open(path, "w") as f:
            f.write(new_content)
        print(f"Cleaned {path}")
PYEOF
  fi
  log_ok "cycle_detail_screen.dart processed"
fi

# Fix cycle_attachments_screen.dart
CYCLE_ATTACH="lib/features/cycles/presentation/screens/cycle_attachments_screen.dart"
if [ -f "$CYCLE_ATTACH" ]; then
  log_step "Disabling cycle_attachments_screen.dart..."
  if [ "$DRY_RUN" = false ]; then
    cat > "$CYCLE_ATTACH" << 'DART_EOF'
import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';

class CycleAttachmentsScreen extends StatelessWidget {
  final String cycleId;
  const CycleAttachmentsScreen({super.key, required this.cycleId});

  @override
  Widget build(BuildContext context) {
    // TODO: Re-enable when backend attachment upload is fixed
    // (see docs/BACKEND_BUGS.md#attachment-upload)
    // Status: Deferred to v1.1 — backend returns 500 on
    //         POST /v1/cycles/{id}/attachments
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppBar(title: const Text('Pièces jointes')),
      body: const EmptyView(
        title: 'Fonctionnalité bientôt disponible',
        message: 'L\'ajout de pièces jointes sera activé dans une '
            'prochaine mise à jour.\n\n'
            'Cette limitation vient du serveur et sera corrigée par '
            'l\'équipe backend.',
        icon: Icons.construction_outlined,
      ),
    );
  }
}
DART_EOF
  fi
  log_ok "cycle_attachments_screen.dart replaced with disabled state"
fi

# Fix receipt_photo_screen.dart if it exists
RECEIPT_PHOTO="lib/features/purchases/presentation/screens/receipt_photo_screen.dart"
if [ -f "$RECEIPT_PHOTO" ]; then
  log_step "Disabling receipt_photo_screen.dart..."
  if [ "$DRY_RUN" = false ]; then
    cat > "$RECEIPT_PHOTO" << 'DART_EOF'
import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';

class ReceiptPhotoScreen extends StatelessWidget {
  final String poId;
  const ReceiptPhotoScreen({super.key, required this.poId});

  @override
  Widget build(BuildContext context) {
    // TODO: Re-enable when backend attachment upload is fixed
    // (see docs/BACKEND_BUGS.md#attachment-upload)
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppBar(title: const Text('Photo de réception')),
      body: const EmptyView(
        title: 'Fonctionnalité bientôt disponible',
        message: 'L\'ajout de photos sera activé dans une '
            'prochaine mise à jour.',
        icon: Icons.construction_outlined,
      ),
    );
  }
}
DART_EOF
  fi
  log_ok "receipt_photo_screen.dart replaced"
fi

# =============================================================================
# T0.3 — WRITE BACKEND_BUGS.md
# =============================================================================
log_section "T0.3 — Write BACKEND_BUGS.md"

if [ "$DRY_RUN" = false ]; then
  cat > docs/BACKEND_BUGS.md << 'MD_EOF'
# Backend Bugs — SteryMed Mobile Blockers

**Filed:** 2026-09-18
**Filed by:** Mobile team
**Assigned to:** Backend team
**Priority:** P0 (blocks pilot)

This document lists every backend issue that blocks the SteryMed Mobile
pilot. Each entry includes the exact `curl` command, the observed
response, the expected response, and the mobile impact.

**Rule:** No bug is considered resolved until the `curl` command returns
the expected response on staging. Screenshots are not evidence.

---

## BUG-001 — Attachment upload returns 500

**Severity:** P0 — blocks entire attachment feature
**Endpoint:** `POST /v1/cycles/{cycle}/attachments`
**Status:** 🔴 Open
**Filed:** 2026-09-18

### Reproduction

```bash
curl -X POST "$STAGING_URL/v1/cycles/$CYCLE_ID/attachments" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/json" \
  -H "Idempotency-Key: bug-001-$(date +%s)" \
  -F "file=@test_upload.png"