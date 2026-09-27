# Prosthetic Module

**Real and live, as of 2026-09-26.** Superseded by
[ADR 0011](adr/0011-prosthetic-module-adopted.md), which supersedes
[ADR 0010](adr/0010-prosthetic-deferred.md) (the original "removed,
do not re-add" decision — kept for the historical record, no longer the
current status).

## What exists

Backend (`steriqore`): a genuine `Prosthetic` domain — migrations,
models, actions, policies, controllers, routes, RLS-scoped like every
other tenant table. Live routes (confirmed against
`GET /docs/api.json`, 78 real paths, and cross-checked in
`test/unit/contract/api_endpoints_test.dart`):

- `GET/POST /v1/prosthetic-cases`, `GET /v1/prosthetic-cases/{id}`
- `GET /v1/prosthetic-cases/waiting-placement`
- `PATCH /v1/prosthetic-cases/{id}` (Quick Edit)
- `POST /v1/prosthetic-cases/{id}/status`, `GET .../status-history`
- `GET/POST /v1/prosthetic-cases/{id}/attachments`,
  `DELETE .../attachments/{media}`
- `GET /v1/prosthetic-dashboard`
- `GET/POST /v1/laboratories`, `GET /v1/laboratories/{id}`

Mobile (`sterymed_mobile`), `lib/features/prosthetic/`:

- **Screens**: home (dashboard), case list, create, detail (with Quick
  Edit, status transitions, payment section, attachments, status-history
  timeline), waiting-for-placement, laboratories.
- **Repository**: `ProstheticRepository` — online reads, `changeStatus`,
  `update`, attachment upload/delete, `waitingForPlacement` (cursor
  pagination), `countLabels`... no offline-outbox writes for this
  domain (unlike stock/cycles) — every mutation here needs the network.
- **Permissions**: `prosthetic_cases.view`, `prosthetic_cases.manage`,
  `prosthetic_payments.manage` — same universal-view /
  role-restricted-manage pattern as every other domain.

**One deliberate deviation from the brief's literal field list:** no
patient First/Last name fields — this app's `Patients` domain is
anonymous by design (`BUG-008`), so a prosthetic case links to the
existing anonymous `patient_id`, not raw name fields. See
`docs/BACKEND_BUGS.md#bug-023`.

## Test coverage

Real, backend-verified coverage across both layers — not fabricated
against the brief's raw field list:

- `test/unit/features/prosthetic/` — draft store round-trip, status
  transitions (mirrors the backend's `allowedNextStatuses()` exactly),
  remaining-balance/payment-due logic, waiting-placement filter logic.
- `test/bloc/prosthetic_list_bloc_test.dart`,
  `prosthetic_status_bloc_test.dart`, `prosthetic_payment_bloc_test.dart`,
  `prosthetic_case_detail_bloc_test.dart` (the latter three are named
  after Blocs that don't exist — these screens use direct
  `setState`/repository calls; the files test that real pattern instead,
  see each file's own header comment).
- `test/widget/prosthetic_form_test.dart`,
  `prosthetic_case_detail_test.dart`, `waiting_placement_screen_test.dart`.

## Known gaps

- **BUG-024**: no print/export endpoint exists for a case — genuinely
  missing on the backend, not implementable yet.
- No offline support for any prosthetic write (status change, payment
  save, attachment upload) — every mutation requires connectivity.
