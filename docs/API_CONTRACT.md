# SteryMed Mobile — API Contract

**Frozen:** 2026-09-22
**Backend commit:** `steriqore` @ `6af6b9c` (verified against live OpenAPI spec, local docker instance, port 8010)
**Staging URL:** http://localhost:8010 (local dev; no staging deployment exists yet)
**Frozen by:** Mobile engineer
**Signed off by:** _pending web/backend engineer sign-off_

Any change to this contract after freeze requires a written change request.

**Honest status, 2026-09-26:** only "1. Conventions" below is actually
written; sections 2–19 exist in the table of contents but were never
filled in (this was true before this note was added, not a regression).
Rather than writing 18 sections of REST documentation by hand — which
would duplicate, and risk drifting from, the backend's own
auto-generated spec — treat these as authoritative instead for anything
not covered here:
- The live spec: `GET /docs/api.json` against a running backend (the
  committed `steriqore` repo's `docs/openapi.yaml` is confirmed
  **stale** — do not use it).
- `lib/core/config/api_endpoints.dart` for every path the mobile app
  actually calls, cross-checked against that live spec by
  `test/unit/contract/api_endpoints_test.dart`.
- `docs/PROSTHETIC_MODULE.md` for prosthetic specifically (section 19
  below is wrong — see that doc instead; prosthetic is real and live,
  not N/A).

---

## Table of Contents

1. Conventions
2. Authentication
3. Alerts
4. Labels
5. Patients
6. Cycles
7. Stock
8. Purchases
9. Suppliers
10. Catalog (Products)
11. Compliance (Non-Conformities)
12. Audit
13. Team
14. Sites
15. Devices
16. DLU Rules
17. Reporting
18. Team Invitations
19. Prosthetic — real and live, not N/A; see `docs/PROSTHETIC_MODULE.md` (ADR 0011)

---

## 1. Conventions

### Base URL
No staging deployment exists — `http://localhost:8010` (local Docker) is
the only environment today. `lib/core/config/env.dart` reads the real
base URL from a compile-time `--dart-define`, not a hardcoded value.

### Headers

| Header | Required on | Value |
|---|---|---|
| `Authorization` | All authenticated endpoints | `Bearer <token>` |
| `Idempotency-Key` | All POST/PATCH/DELETE | UUID v4 |
| `Accept` | Always | `application/json` |
| `Content-Type` | POST/PATCH with body | `application/json` or `multipart/form-data` |

### Response envelope

**Success (single resource):** the resource's own fields, flat (no
wrapper) — e.g. `GET /v1/cycles/{id}` returns the cycle object directly.

**Error** (verified against `app/Support/Api/ApiExceptionRenderer.php`):
```json
{
  "error": {
    "code": "VALIDATION_FAILED",
    "message": "Human-readable message",
    "details": {},
    "request_id": "req-abc123"
  }
}
```
`code` is always `UPPER_SNAKE_CASE` for a genuine server response — the
mobile app branches on `code`, never `message`. See
`lib/core/errors/error_codes.dart`/`error_mapper.dart` and
`test/unit/contract/error_codes_test.dart`.