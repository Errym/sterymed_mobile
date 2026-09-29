#!/usr/bin/env bash
source "$(dirname "$0")/../phase1/_common.sh"

banner "PHASE 2 — MVP Feature Completion"

require_repo_root
require_clean_tree

SCRIPTS=(
  "fix_2_1_waiting_placement_aging.sh"
  "fix_2_2_export_download.sh"
  "fix_2_3_password_reset.sh"
  "fix_2_4_queued_vs_synced.sh"
  "fix_2_5_sync_queue_grouped.sh"
  "fix_2_6_practitioner_dropdown.sh"
  "fix_2_7_outbox_all_writes.sh"
)

for s in "${SCRIPTS[@]}"; do
  echo ""
  log "Running $s"
  if ! "$(dirname "$0")/$s"; then
    fail "$s failed. Stopping."
    fail "Fix the issue, then re-run: scripts/phase2/run_all.sh"
    exit 1
  fi
done

banner "PHASE 2 — SCRIPTS COMPLETE ✅"
warn "FIX 2.1, 2.6, 2.7 have MANUAL steps remaining."
warn "Read the warnings above and complete them."
warn "Then: git status → clean, flutter test → green, git push."