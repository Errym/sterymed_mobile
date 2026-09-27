# ADR 0011 — Prosthetic module adopted, supersedes ADR 0010

## Status
Accepted — 2026-09-26. Supersedes [ADR 0010](./0010-prosthetic-deferred.md).

## Context
ADR 0010 deferred the prosthetic module after finding the original mobile
master prompt listed 10 prosthetic screens with zero corresponding
backend domain, migrations, or routes — the code had been written against
invented, unverified wire shapes.

`pjdocs/SteryMed_Prosthetic_Workflow_Implementation_Brief_EN-compressed.pdf`
is a different document: an internal product brief (not the master
prompt) that explicitly splits ownership between two named engineers —
"Anas" for backend (Laravel domain model, migrations, REST endpoints)
and "Meryem" for mobile (Flutter client) — and specifies a concrete API
surface (`GET/POST /prosthetic-cases`, `/prosthetic-cases/{id}/status`,
`/prosthetic-cases/waiting-placement`, `/prosthetic-dashboard`,
`/laboratories`), a data model, required statuses, and MVP acceptance
criteria.

Live-reverified 2026-09-26, after today's backend rebuild: the backend
still has zero `Prosthetic` domain, zero `prosthetic*` routes, zero
matching migrations. ADR 0010's finding is still factually correct as of
today — this ADR does not dispute that finding, it supersedes the
*scope decision*, because the brief driving the new work is a real,
dated product document with concrete ownership, not a stray
planning-doc reference.

## Decision
Build the module for real, both sides, per the brief:
- Backend (`steriqore`): a genuine `Prosthetic` domain — migrations,
  models, Spatie Data DTOs, actions, policies, controllers, routes —
  following this codebase's existing conventions (RLS-scoped tenant
  tables, `TenantContext::run()` where needed, Spatie Permission grants,
  audit logging via `RecordAuditEventAction`).
- Mobile (`sterymed_mobile`): the client screens described in the brief's
  "Meryem - Mobile responsibilities" section, built against the backend
  contract above once it's live-verified — not against the brief's raw
  field list guessed in isolation.

**One deliberate adaptation from the brief's literal field list:** the
brief's "Create a prosthetic case" screen (page 6) lists patient
`First name`/`Last name` as captured fields. This app's `Patients`
domain was deliberately redesigned earlier this session (BUG-008) to
carry no PII on the wire or on-device — patients are anonymous
references only, by real backend design (`PatientData` has no name
fields; only the app's own generated reference). A prosthetic case
links to a `patient_id` (the existing anonymous patient record), not raw
name fields, so this module doesn't reopen the PII question ADR 0010's
sibling decision already closed.

## Consequences
- The permission model gains three new grants
  (`prosthetic_cases.view`, `prosthetic_cases.manage`,
  `prosthetic_payments.manage`), assigned in
  `SeedTenantRolesAction` following the same universal-view /
  role-restricted-manage pattern as every other domain.
- If the backend build reveals the brief's suggested shape needs to
  change (e.g. a field that doesn't fit the existing patient/audit
  model), the deviation is documented at the point it's made, not
  silently — same standard as every other domain built this session.
- Unlike the deleted ADR-0010 code, every mobile field/screen in this
  rebuild is built against a contract confirmed live on the running
  backend before being trusted, per this session's standing
  no-fabrication rule.
