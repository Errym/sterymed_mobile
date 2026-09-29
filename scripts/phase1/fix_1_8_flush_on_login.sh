#!/usr/bin/env bash
source "$(dirname "$0")/_common.sh"

banner "FIX 1.8 — Flush outbox on login success"

require_repo_root
require_clean_tree

FILE="lib/features/auth/presentation/bloc/auth_bloc.dart"
backup_file "$FILE"

# Ensure imports.
ensure_import "$FILE" "import 'dart:async';"
ensure_import "$FILE" "import '../../../../core/sync/sync_status_cubit.dart';"
ensure_import "$FILE" "import '../../../../di/di.dart';"

# Insert the flush call after each successful login/register.
python3 - "$FILE" <<'PYEOF'
import sys, io

path = sys.argv[1]
with io.open(path, encoding='utf-8') as f:
    src = f.read()

# After login success:
src = src.replace(
    "await _repository.login(\n        tenantSlug: event.tenantSlug,\n        email: event.email,\n        password: event.password,\n      );\n      emit(const AuthAuthenticated());",
    "await _repository.login(\n        tenantSlug: event.tenantSlug,\n        email: event.email,\n        password: event.password,\n      );\n      unawaited(getIt<SyncStatusCubit>().refreshNow());\n      emit(const AuthAuthenticated());",
)

# After register success:
src = src.replace(
    "await _repository.register(\n        tenantName: event.tenantName,\n        tenantSlug: event.tenantSlug,\n        ownerName: event.ownerName,\n        ownerEmail: event.ownerEmail,\n        password: event.password,\n      );\n      emit(const AuthAuthenticated());",
    "await _repository.register(\n        tenantName: event.tenantName,\n        tenantSlug: event.tenantSlug,\n        ownerName: event.ownerName,\n        ownerEmail: event.ownerEmail,\n        password: event.password,\n      );\n      unawaited(getIt<SyncStatusCubit>().refreshNow());\n      emit(const AuthAuthenticated());",
)

with io.open(path, 'w', encoding='utf-8') as f:
    f.write(src)

print("Patched auth_bloc.dart")
PYEOF

# Verify the replacement actually landed.
if ! grep -q "unawaited(getIt<SyncStatusCubit>().refreshNow());" "$FILE"; then
  fail "Replacement did not apply — check the anchor strings in auth_bloc.dart"
  exit 1
fi
ok "Inserted flush calls"

run_analyze
commit_fix "fix(auth): flush outbox on login and register success" "$FILE"

ok "FIX 1.8 complete"