#!/usr/bin/env bash
# Common helpers for Phase 1 fix scripts.
# Source this at the top of every fix script:
#   source "$(dirname "$0")/_common.sh"

set -euo pipefail

# ── Colors ─────────────────────────────────────────────────────────────
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[0;33m'
BLUE=$'\033[0;34m'
BOLD=$'\033[1m'
NC=$'\033[0m'

# ── Paths ──────────────────────────────────────────────────────────────
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BACKUP_DIR="$REPO_ROOT/_script_backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# ── Logging ────────────────────────────────────────────────────────────
log()  { echo "${BLUE}▸${NC} $*"; }
ok()   { echo "${GREEN}✓${NC} $*"; }
warn() { echo "${YELLOW}⚠${NC} $*"; }
fail() { echo "${RED}✗${NC} $*" >&2; }

# ── Safety ─────────────────────────────────────────────────────────────
require_repo_root() {
  cd "$REPO_ROOT"
  if [[ ! -f "pubspec.yaml" ]]; then
    fail "Not in a Flutter repo root. pubspec.yaml missing at $REPO_ROOT."
    exit 1
  fi
}

require_clean_tree() {
  if [[ -n "$(git status --porcelain)" ]]; then
    fail "Working tree is dirty. Commit or stash your changes before running fix scripts."
    git status --short
    exit 1
  fi
}

backup_file() {
  local f="$1"
  if [[ -f "$f" ]]; then
    local dest="$BACKUP_DIR/$(echo "$f" | tr '/' '_')"
    cp "$f" "$dest"
    log "Backed up $f → $dest"
  fi
}

# ── File mutation ──────────────────────────────────────────────────────
# append_after <file> <anchor> <payload>
# Appends <payload> immediately after the first line matching <anchor>.
append_after() {
  local file="$1"
  local anchor="$2"
  local payload="$3"

  if grep -qF "$payload" "$file"; then
    ok "Already present in $file — skipping append"
    return 0
  fi

  local line_num
  line_num=$(grep -nF "$anchor" "$file" | head -n1 | cut -d: -f1 || true)
  if [[ -z "$line_num" ]]; then
    fail "Anchor not found in $file: $anchor"
    return 1
  fi

  local tmp
  tmp=$(mktemp)
  head -n "$line_num" "$file" > "$tmp"
  printf '%s\n' "$payload" >> "$tmp"
  tail -n +"$((line_num + 1))" "$file" >> "$tmp"
  mv "$tmp" "$file"
  ok "Inserted after line $line_num in $file"
}

# replace_block <file> <start_pattern> <end_pattern> <payload>
# Replaces everything from the line matching <start_pattern> to the line
# matching <end_pattern> (inclusive) with <payload>.
replace_block() {
  local file="$1"
  local start_pat="$2"
  local end_pat="$3"
  local payload="$4"

  local start_line end_line
  start_line=$(grep -nF "$start_pat" "$file" | head -n1 | cut -d: -f1 || true)
  end_line=$(grep -nF "$end_pat" "$file" | head -n1 | cut -d: -f1 || true)

  if [[ -z "$start_line" || -z "$end_line" ]]; then
    fail "Could not locate block in $file"
    fail "  start: $start_pat (line: ${start_line:-?})"
    fail "  end:   $end_pat (line: ${end_line:-?})"
    return 1
  fi
  if (( end_line < start_line )); then
    fail "End marker appears before start marker in $file"
    return 1
  fi

  local tmp
  tmp=$(mktemp)
  head -n "$((start_line - 1))" "$file" > "$tmp"
  printf '%s\n' "$payload" >> "$tmp"
  tail -n +"$((end_line + 1))" "$file" >> "$tmp"
  mv "$tmp" "$file"
  ok "Replaced lines $start_line–$end_line in $file"
}

# ensure_import <file> <import_line>
# Adds an import if it isn't already present, inserting it alphabetically
# among the last block of imports.
ensure_import() {
  local file="$1"
  local line="$2"

  if grep -qF "$line" "$file"; then
    ok "Import already present in $file"
    return 0
  fi

  local last_import
  last_import=$(grep -n "^import " "$file" | tail -n1 | cut -d: -f1 || true)
  if [[ -z "$last_import" ]]; then
    fail "No imports found in $file"
    return 1
  fi

  local tmp
  tmp=$(mktemp)
  head -n "$last_import" "$file" > "$tmp"
  printf '%s\n' "$line" >> "$tmp"
  tail -n +"$((last_import + 1))" "$file" >> "$tmp"
  mv "$tmp" "$file"
  ok "Added import to $file"
}

# ── Verification ───────────────────────────────────────────────────────
run_analyze() {
  log "flutter analyze"
  if ! flutter analyze; then
    fail "flutter analyze failed."
    return 1
  fi
  ok "analyze clean"
}

run_tests() {
  log "flutter test"
  if ! flutter test --reporter compact; then
    fail "flutter test failed."
    return 1
  fi
  ok "tests passed"
}

commit_fix() {
  local msg="$1"
  local -a paths=("${@:2}")

  git add -- "${paths[@]}"
  git commit -m "$msg" >/dev/null
  ok "committed: $msg"
}

banner() {
  echo ""
  echo "${BOLD}════════════════════════════════════════════════════════════${NC}"
  echo "${BOLD}  $*${NC}"
  echo "${BOLD}════════════════════════════════════════════════════════════${NC}"
}