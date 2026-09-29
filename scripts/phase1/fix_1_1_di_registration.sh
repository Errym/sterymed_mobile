#!/usr/bin/env bash
source "$(dirname "$0")/_common.sh"

banner "FIX 1.1 — Register MaintenanceRecordRepository in DI"

require_repo_root
require_clean_tree

FILE="lib/di/features_di.dart"
backup_file "$FILE"

# 1. Ensure imports
ensure_import "$FILE" "import '../features/devices/data/datasources/maintenance_record_datasource.dart';"
ensure_import "$FILE" "import '../features/devices/data/repositories/maintenance_record_repository.dart';"

# 2. Idempotency check
if grep -q "MaintenanceRecordRepository" "$FILE" && \
   grep -q "registerLazySingleton<MaintenanceRecordRepository>" "$FILE"; then
  ok "MaintenanceRecordRepository already registered — nothing to do"
  exit 0
fi

# 3. Insert the registrations right after the DeviceDetailRepository block.
#    Anchor on the closing of the DeviceDetailRepository registration.
ANCHOR="() => DeviceDetailRepository("

# Find the anchor line, then find the next ");" that closes it.
LINE=$(grep -nF "$ANCHOR" "$FILE" | head -n1 | cut -d: -f1 || true)
if [[ -z "$LINE" ]]; then
  fail "DeviceDetailRepository registration not found in $FILE"
  exit 1
fi

# Find the matching closing ");" after $LINE
CLOSING=$(awk -v start="$LINE" 'NR>=start && /^\);$/ {print NR; exit}' "$FILE")
if [[ -z "$CLOSING" ]]; then
  fail "Could not find closing of DeviceDetailRepository block"
  exit 1
fi

PAYLOAD=$(cat <<'DART'

  getIt.registerLazySingleton<MaintenanceRecordDatasource>(
    () => MaintenanceRecordDatasource(getIt<DioClient>().dio),
  );
  getIt.registerLazySingleton<MaintenanceRecordRepository>(
    () => MaintenanceRecordRepository(
      getIt<MaintenanceRecordDatasource>(),
      getIt<AppCache>(),
    ),
  );
DART
)

TMP=$(mktemp)
head -n "$CLOSING" "$FILE" > "$TMP"
printf '%s\n' "$PAYLOAD" >> "$TMP"
tail -n +"$((CLOSING + 1))" "$FILE" >> "$TMP"
mv "$TMP" "$FILE"

ok "Inserted MaintenanceRecordRepository registration after line $CLOSING"

run_analyze
commit_fix "fix(di): register MaintenanceRecordRepository — was crashing device detail" "$FILE"

ok "FIX 1.1 complete"