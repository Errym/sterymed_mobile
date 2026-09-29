#!/usr/bin/env bash
source "$(dirname "$0")/../phase1/_common.sh"

banner "FIX 2.2 — Real file download + open for exports"

require_repo_root
require_clean_tree

PUBSPEC="pubspec.yaml"
SERVICE="lib/features/reporting/data/services/export_download_service.dart"
DI="lib/di/features_di.dart"
SNACK="lib/shared/widgets/feedback/app_snackbar.dart"
SCREEN="lib/features/reporting/presentation/screens/data_export_request_screen.dart"

backup_file "$PUBSPEC"
backup_file "$DI"
backup_file "$SNACK"
backup_file "$SCREEN"

# ── 1. Add open_filex to pubspec.yaml if missing ─────────────────────
if grep -q "open_filex:" "$PUBSPEC"; then
  ok "open_filex already in pubspec.yaml"
else
  python3 - "$PUBSPEC" <<'PYEOF'
import io, sys

path = sys.argv[1]
with io.open(path, encoding='utf-8') as f:
    src = f.read()

# Insert after "path_provider: ^2.1.4" line.
anchor = "path_provider: ^2.1.4"
if anchor in src:
    src = src.replace(anchor, anchor + "\n  open_filex: ^4.5.0", 1)
else:
    print("Anchor not found — insert open_filex manually", file=sys.stderr)
    sys.exit(1)

with io.open(path, 'w', encoding='utf-8') as f:
    f.write(src)

print("Added open_filex to pubspec.yaml")
PYEOF
  log "flutter pub get"
  flutter pub get
fi

# ── 2. Create ExportDownloadService if missing ───────────────────────
mkdir -p "$(dirname "$SERVICE")"
if [[ -f "$SERVICE" ]]; then
  ok "$SERVICE already exists — skipping creation"
else
  cat > "$SERVICE" <<'DART'
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/errors/api_exception.dart';

/// Downloads a completed export archive to a local temp file so the client
/// can actually retrieve the ZIP (MVP brief). Uses a *bare* Dio (no
/// auth/base-URL interceptors): the export download URL is a fully-qualified,
/// presigned object-storage link, not a `/v1` API route, so it must not
/// carry the app's bearer token or be rewritten against the API base URL.
class ExportDownloadService {
  final Dio _dio;
  ExportDownloadService(this._dio);

  Future<File> download({
    required String url,
    required String suggestedFileName,
  }) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$suggestedFileName');
      await _dio.download(url, file.path);
      return file;
    } on DioException catch (e) {
      throw ApiException(
        code: 'download_failed',
        message: 'Téléchargement impossible. Vérifiez votre connexion.',
        statusCode: e.response?.statusCode,
      );
    }
  }
}
DART
  ok "Created $SERVICE"
fi

# ── 3. Register in DI ─────────────────────────────────────────────────
ensure_import "$DI" "import '../features/reporting/data/services/export_download_service.dart';"
ensure_import "$DI" "import '../core/network/dio_factory.dart';"

if ! grep -q "registerLazySingleton<ExportDownloadService>" "$DI"; then
  # Insert after ExportRepository registration.
  ANCHOR="getIt.registerLazySingleton<ExportRepository>"
  LINE=$(grep -nF "$ANCHOR" "$DI" | head -n1 | cut -d: -f1 || true)
  if [[ -z "$LINE" ]]; then
    fail "ExportRepository registration not found in $DI"
    exit 1
  fi
  CLOSING=$(awk -v start="$LINE" 'NR>=start && /^  \);$/ {print NR; exit}' "$DI")
  if [[ -z "$CLOSING" ]]; then
    fail "Could not find closing of ExportRepository block"
    exit 1
  fi
  PAYLOAD=$(cat <<'DART'

  // Bare Dio on purpose: the download URL is a presigned object-storage
  // link, not a /v1 API route — it must not carry the bearer token or be
  // rewritten against the API base URL.
  getIt.registerLazySingleton<ExportDownloadService>(
    () => ExportDownloadService(DioFactory.bare()),
  );
DART
)
  TMP=$(mktemp)
  head -n "$CLOSING" "$DI" > "$TMP"
  printf '%s\n' "$PAYLOAD" >> "$TMP"
  tail -n +"$((CLOSING + 1))" "$DI" >> "$TMP"
  mv "$TMP" "$DI"
  ok "Registered ExportDownloadService in DI"
else
  ok "ExportDownloadService already registered"
fi

# ── 4. Add actionLabel/onAction to AppSnackbar ────────────────────────
if grep -q "actionLabel" "$SNACK"; then
  ok "AppSnackbar already supports actions"
else
  cat > "$SNACK" <<'DART'
import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

enum SnackKind { info, success, warning, error, queued }

abstract final class AppSnackbar {
  static void show(
    BuildContext context,
    String message, {
    SnackKind kind = SnackKind.info,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    Color bg;
    IconData icon;
    switch (kind) {
      case SnackKind.success:
        bg = AppColors.success;
        icon = Icons.check_circle_outline;
        break;
      case SnackKind.warning:
        bg = AppColors.warning;
        icon = Icons.warning_amber_outlined;
        break;
      case SnackKind.error:
        bg = AppColors.danger;
        icon = Icons.error_outline;
        break;
      case SnackKind.info:
        bg = AppColors.brandPrimary;
        icon = Icons.info_outline;
        break;
      case SnackKind.queued:
        bg = AppColors.info;
        icon = Icons.cloud_upload_outlined;
        break;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: bg,
          duration: Duration(seconds: actionLabel != null ? 6 : 4),
          action: (actionLabel != null && onAction != null)
              ? SnackBarAction(
                  label: actionLabel,
                  textColor: AppColors.textOnBrand,
                  onPressed: onAction,
                )
              : null,
          content: Row(
            children: [
              Icon(icon, color: AppColors.textOnBrand, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textOnBrand,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }
}
DART
  ok "Rewrote AppSnackbar with action support"
fi

# ── 5. Wire the export screen _download method ────────────────────────
ensure_import "$SCREEN" "import 'package:open_filex/open_filex.dart';"
ensure_import "$SCREEN" "import '../../data/services/export_download_service.dart';"

python3 - "$SCREEN" <<'PYEOF'
import io, sys, re

path = sys.argv[1]
with io.open(path, encoding='utf-8') as f:
    src = f.read()

# Replace _download body if it still uses Clipboard.
new_method = r'''  Future<void> _download(ExportRequestData export) async {
    try {
      setState(() => _downloadingId = export.id);
      final url = await getIt<ExportRepository>().downloadUrl(export.id);
      if (!mounted) return;
      final file = await getIt<ExportDownloadService>().download(
        url: url,
        suggestedFileName:
            'steriymed-export-${export.id.substring(0, 8)}.zip',
      );
      if (!mounted) return;
      AppSnackbar.show(
        context,
        'Téléchargement terminé.',
        kind: SnackKind.success,
        actionLabel: 'Ouvrir',
        onAction: () => OpenFilex.open(file.path),
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, ErrorMessage.from(e), kind: SnackKind.error);
    } finally {
      if (mounted) setState(() => _downloadingId = null);
    }
  }'''

# Match the old _download method.
pattern = re.compile(
    r"  Future<void> _download\(ExportRequestData export\) async \{.*?\n  \}",
    re.DOTALL,
)
src, n = pattern.subn(new_method, src, count=1)

if n == 0:
    print("Could not find _download method — inspect manually", file=sys.stderr)
    sys.exit(1)

# Ensure _downloadingId field exists.
if "_downloadingId" not in src.split("Future<void> _download")[0]:
    # Add field inside the state class after the first `{` of `class _...State`
    marker = re.search(r"class _\w+State extends State<\w+> \{", src)
    if marker:
        insert_at = marker.end()
        src = src[:insert_at] + "\n  String? _downloadingId;\n" + src[insert_at:]

with io.open(path, 'w', encoding='utf-8') as f:
    f.write(src)

print("Wired _download in export screen")
PYEOF

# ErrorMessage import (needed for the new catch).
ensure_import "$SCREEN" "import '../../../../core/utils/error_message.dart';"

run_analyze
run_tests
commit_fix "feat(reporting): real file download + open for exports" \
  "$PUBSPEC" "$SERVICE" "$DI" "$SNACK" "$SCREEN" "pubspec.lock"

ok "FIX 2.2 complete"