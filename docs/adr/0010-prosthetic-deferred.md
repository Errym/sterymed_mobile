# ADR 0010 — Prosthetic module deferred to v1.1

## Status
Accepted — 2026-09-15

## Context
The SteryMed Mobile master prompt (Section 7) lists 10 prosthetic screens as
in-scope for the pilot. Section 2.2 of the same prompt flagged that the
backend prosthetic domain may not exist and required verification before
building or keeping any prosthetic code.

## Evidence (captured 2026-09-15, live backend at localhost:8010 via
`docker exec steriqore-app`)

1. `app/Domain` contains exactly these domains: `Catalog`, `Compliance`,
   `Equipment`, `Identity`, `Inventory`, `Labeling`, `Purchasing`,
   `Reporting`, `Sterilization`, `Tenancy`, `Traceability`.
   **No `Prosthetic` domain.**
2. `database/migrations` contains **zero** migrations matching `prosthetic`.
3. `php artisan route:list --path=api --json` (saved to
   `docs/backend_routes.json`, 92 routes) contains **zero** routes matching
   `prosthetic` or `laboratory`. There is no `/v1/prosthetic-cases`,
   `/v1/laboratories`, or any related endpoint.

This confirms, with direct evidence from the live backend, that the
prosthetic domain does not exist server-side.

## Decision
Deleted `lib/features/prosthetic/` in its entirety (60 files: data sources,
models, repositories, blocs, screens, widgets). Removed:
- The `ProstheticListScreen` import and its `GoRoute` from
  `lib/core/router/app_router.dart`.
- All `prosthetic*` constants from `lib/core/router/routes.dart` and
  `lib/core/router/route_names.dart`.

No DI registrations, l10n keys, or shell bottom-nav entries referenced
prosthetic, so no changes were needed there.

## Consequences
- The mobile pilot ships without a prosthetic module, matching backend
  reality. The bottom nav is unaffected (it never had a prosthetic tab).
- `flutter analyze` remains clean and `flutter build web --debug` still
  succeeds after removal (verified).
- If the backend ships a prosthetic domain in the future, this ADR should be
  superseded and the module rebuilt against the real wire shapes captured at
  that time — not against the deleted code, which was written against
  invented/assumed shapes that were never verified.
