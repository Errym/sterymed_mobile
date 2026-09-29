# Backend Issues — Mobile Workarounds

**Last verified against backend**: 2026-09-28
**Rule**: Every mobile workaround MUST reference a BE-XXX ID. Closing a BE-XXX = removing the workaround in the same PR.

| ID | Endpoint | Symptom | Mobile Workaround | File | Status |
|----|----------|---------|-------------------|------|--------|
| BE-001 | GET /v1/sites/{id} | 404 | `ApiEndpoints.site()` is dead code | core/config/api_endpoints.dart:48 | OPEN |
| BE-002 | GET /v1/locations | 404 | Derive from `/stock-levels` | stock/data/datasources/stock_remote_datasource.dart:41 | OPEN |
| BE-003 | GET /v1/batches | 404 | Derive from `/stock-levels` | stock/presentation/screens/batch_list_screen.dart:36 | OPEN |
| BE-007 | PATCH /v1/cycles/{id} | 404 | Notes cached locally (Hive) | cycles/data/local/cycle_notes_cache.dart | **CRITICAL** |
| BE-010 | Presigned MinIO URLs | Return `minio:9000` | Rewrite host to `localhost`/`10.0.2.2` | core/utils/media_url.dart:22 | OPEN |
| BE-024 | Prosthetic PDF export | No server endpoint | Client-side PDF via `printing` | prosthetic/.../prosthetic_case_pdf.dart | OPEN |
| BE-025 | GET /v1/sites/{id} | 404 | Dead code, unused | core/config/api_endpoints.dart:48 | OPEN |

## Notes
- BE-010: MinIO presigned URLs return the Docker-internal hostname `minio`. Non-web clients can't resolve it. Workaround rewrites to `localhost:9000` (web) or `10.0.2.2:9000` (native). **Do not remove in release builds.**
- BE-007: Cycle notes are stored ONLY on-device via Hive. See Phase 0.2 for the user-facing mitigation.