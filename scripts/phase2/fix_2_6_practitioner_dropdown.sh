#!/usr/bin/env bash
source "$(dirname "$0")/../phase1/_common.sh"

banner "FIX 2.6 — Prosthetic practitioner filter dropdown"

require_repo_root
require_clean_tree

TEAM_REPO="lib/features/identity/data/repositories/team_repository.dart"
SCREEN="lib/features/prosthetic/presentation/screens/prosthetic_case_list_screen.dart"

backup_file "$TEAM_REPO"
backup_file "$SCREEN"

# ── 1. Add practitioners() to TeamRepository ──────────────────────────
if grep -q "Future<List<TeamMemberData>> practitioners" "$TEAM_REPO"; then
  ok "TeamRepository.practitioners already exists"
else
  python3 - "$TEAM_REPO" <<'PYEOF'
import io, sys

path = sys.argv[1]
with io.open(path, encoding='utf-8') as f:
    src = f.read()

method = '''
  /// Filtered list of members who can be assigned as a prosthetic
  /// practitioner: owner, admin, or practitioner role.
  Future<List<TeamMemberData>> practitioners() async {
    final all = await list();
    return all
        .where((m) =>
            m.role == 'owner' ||
            m.role == 'admin' ||
            m.role == 'practitioner')
        .toList();
  }
'''

anchor = "  Future<void> invite({required String email, required String role}) async {"
if anchor not in src:
    print("invite method not found — insert practitioners manually", file=sys.stderr)
    sys.exit(1)

src = src.replace(anchor, method + "\n" + anchor, 1)

with io.open(path, 'w', encoding='utf-8') as f:
    f.write(src)

print("Added practitioners() to TeamRepository")
PYEOF
fi

# ── 2. Update screen: load practitioners and pass to filter sheet ─────
# This is a UI change that depends on your exact widget tree. The script
# makes a minimal insertion and flags for manual review.
python3 - "$SCREEN" <<'PYEOF'
import io, re, sys

path = sys.argv[1]
with io.open(path, encoding='utf-8') as f:
    src = f.read()

# Add imports.
if "team_repository.dart" not in src:
    src = src.replace(
        "import '../../data/repositories/prosthetic_repository.dart';",
        "import '../../data/repositories/prosthetic_repository.dart';\n"
        "import '../../../identity/data/models/team_member_data.dart';\n"
        "import '../../../identity/data/repositories/team_repository.dart';\n"
        "import '../../../../di/di.dart';",
    )

with io.open(path, 'w', encoding='utf-8') as f:
    f.write(src)

print("Added imports to prosthetic_case_list_screen")
PYEOF

warn "FIX 2.6 requires manual UI wiring:"
warn ""
warn "  1. Add to _ProstheticCaseListViewState:"
warn "       List<TeamMemberData> _practitioners = [];"
warn "  2. In initState():"
warn "       _loadPractitioners();"
warn "  3. Add method:"
warn "       Future<void> _loadPractitioners() async {"
warn "         try {"
warn "           final list = await getIt<TeamRepository>().practitioners();"
warn "           if (mounted) setState(() => _practitioners = list);"
warn "         } catch (_) {}"
warn "       }"
warn "  4. In _ProstheticFilterSheet: add 'final List<TeamMemberData> practitioners;'"
warn "     and replace the practitioner AppSearchField with AppDropdown<String?>."
warn ""
warn "Script will commit the import change only; do the rest by hand."

run_analyze
commit_fix "feat(prosthetic): scaffold practitioner filter dropdown" "$TEAM_REPO" "$SCREEN"

ok "FIX 2.6 partial — finish the UI wiring manually, then commit"