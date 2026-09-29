#!/usr/bin/env bash
source "$(dirname "$0")/_common.sh"

banner "FIX 1.6 — Kill raw e.toString() in UI"

require_repo_root
require_clean_tree

# ── 1. Harden ErrorMessage ────────────────────────────────────────────
EM="lib/core/utils/error_message.dart"
backup_file "$EM"

cat > "$EM" <<'DART'
import '../errors/api_exception.dart';

/// Turns any exception into a clean, user-facing French string.
///
/// The API already returns French messages; this strips the boilerplate
/// `ApiException(code: ..., status: ...)` wrapper and keeps just the message.
/// Every catch block in the app should route through here — never show a
/// raw `e.toString()` to a user.
abstract final class ErrorMessage {
  static String from(Object error) {
    if (error is ApiException) {
      if (error.message.isNotEmpty) return error.message;
      switch (error.code) {
        case 'unauthenticated':
          return 'Session expirée. Veuillez vous reconnecter.';
        case 'forbidden':
          return 'Accès refusé.';
        case 'not_found':
          return 'Ressource introuvable.';
        case 'validation_error':
          return 'Données invalides. Vérifiez les champs.';
        case 'conflict':
          return 'Conflit détecté — la donnée existe déjà.';
        case 'rate_limited':
          return 'Trop de requêtes. Réessayez dans un instant.';
        case 'server_error':
          return 'Erreur serveur. Réessayez plus tard.';
        case 'network_error':
          return 'Connexion impossible. Vérifiez votre réseau.';
        case 'timeout':
          return 'Délai dépassé. Réessayez.';
        default:
          return 'Une erreur est survenue.';
      }
    }

    final s = error.toString();
    final m = RegExp(r'message:\s*([^,)]+)').firstMatch(s);
    if (m != null) return m.group(1)!.trim();
    if (s.startsWith('Exception: ')) {
      return s.substring('Exception: '.length);
    }
    return 'Une erreur inattendue est survenue. Réessayez.';
  }
}
DART
ok "Hardened $EM"

# ── 2. Sweep all files for e.toString() in UI contexts ────────────────
# Target only files under lib/features (skip core/ where debugPrint is fine).
CHANGED=()
while IFS= read -r file; do
  if grep -q "e.toString()" "$file"; then
    backup_file "$file"
    # Replace in AppSnackbar.show calls:
    perl -i -pe 's/AppSnackbar\.show\(\s*context,\s*e\.toString\(\)/AppSnackbar.show(context, ErrorMessage.from(e)/g' "$file"
    # Replace '$e' patterns in snackbars:
    perl -i -pe "s/AppSnackbar\.show\(\s*context,\s*'\\\$e'/AppSnackbar.show(context, ErrorMessage.from(e)/g" "$file"
    # Catch-all: any remaining "e.toString()" inside show( after a comma.
    perl -i -pe 's/(\bshow\([^)]*?,\s*)e\.toString\(\)/${1}ErrorMessage.from(e)/g' "$file"

    # Add the ErrorMessage import if missing.
    if grep -q "ErrorMessage.from" "$file" && ! grep -q "utils/error_message.dart" "$file"; then
      # Find depth: count how many ../ are needed based on 'features/'.
      # We assume the file is under lib/features/<feature>/<layer>/<file>.dart
      # → need ../../../.. for 4-level features, but many are deeper. Use the
      # path prefix to compute depth.
      rel="${file#lib/}"
      depth=$(awk -F'/' '{print NF-1}' <<< "$rel")
      # depth is number of slashes in path relative to lib/
      # Import path: '../' * (depth+1) + 'core/utils/error_message.dart'
      prefix=""
      for ((i=0; i<=depth; i++)); do prefix+="../"; done
      IMP="import '${prefix}core/utils/error_message.dart';"
      if ! grep -qF "$IMP" "$file"; then
        # Insert after the last existing import.
        LAST_IMPORT=$(grep -n "^import " "$file" | tail -n1 | cut -d: -f1)
        if [[ -n "$LAST_IMPORT" ]]; then
          TMP=$(mktemp)
          head -n "$LAST_IMPORT" "$file" > "$TMP"
          printf '%s\n' "$IMP" >> "$TMP"
          tail -n +"$((LAST_IMPORT + 1))" "$file" >> "$TMP"
          mv "$TMP" "$file"
        fi
      fi
    fi
    CHANGED+=("$file")
  fi
done < <(grep -rl "e.toString()" lib/features --include="*.dart" || true)

if [[ ${#CHANGED[@]} -eq 0 ]]; then
  ok "No raw e.toString() found in lib/features — nothing to do"
  exit 0
fi

log "Patched ${#CHANGED[@]} files"
for f in "${CHANGED[@]}"; do
  log "  $f"
done

# ── 3. Any remaining offenders? ──────────────────────────────────────
REMAINING=$(grep -rn "e.toString()" lib/features --include="*.dart" || true)
if [[ -n "$REMAINING" ]]; then
  warn "Remaining raw e.toString() (probably in a debugPrint or toString):"
  echo "$REMAINING"
fi

run_analyze
commit_fix "fix(errors): never surface raw exceptions — always ErrorMessage.from" \
  "$EM" "${CHANGED[@]}"

ok "FIX 1.6 complete"