#!/usr/bin/env bash
source "$(dirname "$0")/_common.sh"

banner "PHASE 1 — Trust Foundation"

require_repo_root
require_clean_tree

SCRIPTS=(
  "fix_1_1_di_registration.sh"
  "fix_1_2_subject_type_label.sh"
  "fix_1_3_role_guard_filter.sh"
  "fix_1_4_nc_filter_chips.sh"
  "fix_1_5_hive_flush.sh"
  "fix_1_6_error_message.sh"
  "fix_1_7_verify_idempotency.sh"
  "fix_1_8_flush_on_login.sh"
  "fix_1_9_haptics.sh"
  "fix_1_10_sync_pill.sh"
)

for s in "${SCRIPTS[@]}"; do
  echo ""
  log "Running $s"
  if ! "$(dirname "$0")/$s"; then
    fail "$s failed. Stopping."
    fail "Fix the issue, then re-run: scripts/phase1/run_all.sh"
    exit 1
  fi
done

banner "PHASE 1 COMPLETE ✅"
ok "All 10 fixes applied and committed."
log "Next: run on a real device and verify the manual checklist."
log "Manual checklist: see end of Phase 1 in the roadmap."