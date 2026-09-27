# Role Matrix

The backend has six roles; the app must respect all of them. The pilot
will seed two accounts (one admin, one staff), but role-aware navigation
and permission gating must work for all six, because the client never
hardcodes role names — it reads whatever permissions the backend granted
this session.

## The model: permission-based, not role-based

`lib/core/router/guards/role_guard.dart` maps routes to permission
strings and checks them against `SessionStore.hasPermission()`, which
reads whatever `permissions` array the backend returned on
`/v1/auth/login` / `/v1/me` — the client never hardcodes a role name.
Several screens additionally gate individual mutating actions (buttons)
the same way, on routes that are otherwise reachable for viewing.

This means the mobile app **already supports all six backend roles**
without needing to know their names — it just reacts to whichever
permissions a given user's role actually grants. Adding a seventh role
backend-side, or changing what a role grants, requires zero mobile code
changes as long as the permission *strings* stay the same.

## The six backend roles

Per `steriqore`'s `SeedTenantRolesAction` (`app/Domain/Identity/Actions/SeedTenantRolesAction.php`):

`owner`, `admin`, `stock_manager`, `releaser`, `practitioner`, `viewer`.

## Permission → role grants (backend source of truth)

| Permission | owner | admin | stock_manager | releaser | practitioner | viewer |
|---|---|---|---|---|---|---|
| `sites.view` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `sites.manage` | ✓ | ✓ | | | | |
| `audit.view` | ✓ | ✓ | | | | |
| `products.view` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `products.manage` | ✓ | ✓ | ✓ | | | |
| `suppliers.view` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `suppliers.manage` | ✓ | ✓ | ✓ | | | |
| `purchasing.view` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `purchasing.manage` | ✓ | ✓ | ✓ | | | |
| `inventory.view` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `inventory.manage` | ✓ | ✓ | ✓ | | | |
| `alerts.view` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `alerts.manage` | ✓ | ✓ | ✓ | | | |
| `devices.view` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `devices.manage` | ✓ | ✓ | ✓ | | | |
| `cycles.view` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `cycles.manage` | ✓ | ✓ | ✓ | | | |
| `cycles.release` | ✓ | ✓ | | ✓ | | |
| `labels.view` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `labels.manage` | ✓ | ✓ | ✓ | | | |
| `patients.view` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `patients.manage` | ✓ | ✓ | | | ✓ | |
| `usages.view` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `usages.manage` | ✓ | ✓ | | | ✓ | |
| `non_conformities.view` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `non_conformities.manage` | ✓ | ✓ | | ✓ | | |
| `data_exports.manage` | ✓ | ✓ | | | | |
| `prosthetic_cases.view` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `prosthetic_cases.manage` | ✓ | ✓ | | | ✓ | |
| `prosthetic_payments.manage` | ✓ | ✓ | | | | |
| `invitations.create` | ✓ | ✓ | | | | |
| `invitations.revoke` | ✓ | ✓ | | | | |
| `memberships.disable` | ✓ | ✓ | | | | |
| `exports.manage` | ✓ | ✓ | | | | |
| `practice_settings.manage` | ✓ | ✓ | | | | |
| `evidence_settings.manage` | ✓ | | | | | |

`evidence_settings.manage` is the one place this backend distinguishes
`owner` from `admin` at all — every other permission treats them
identically. It gates the label-format and DLU-rule sections
specifically (`Routes.dluRules` in the mobile app).

## Permissions actually referenced in this app

28 of the 36 backend permissions are checked somewhere in this codebase
(route guard or in-screen action gate) — 3 more than before ADR 0011's
prosthetic module (`prosthetic_cases.view`/`.manage`,
`prosthetic_payments.manage`), all three gated (see the table below).
The other 8 (`invitations.revoke`, `memberships.disable`, `sites.manage`,
`alerts.manage`, `labels.manage`, `usages.view`, `exports.manage`,
`practice_settings.manage`) aren't referenced anywhere — either there's
no mobile screen for that action yet, or the screen exists but doesn't
gate it (worth a follow-up audit, not assumed safe).

| Permission | Where it's checked |
|---|---|
| `labels.view` | Scanner tab, label detail/blocked routes |
| `usages.manage` | Recording label usage |
| `cycles.view` | Cycles tab, cycle detail/items/control-tests/attachments routes |
| `cycles.manage` | Cycle create route; in-screen: item/control-test/attachment add, start/complete/submit actions |
| `cycles.release` | Cycle release route; in-screen: the release-decision action |
| `inventory.view` | Stock tab |
| `inventory.manage` | Stock issue/adjust/transfer routes |
| `alerts.view` | Alerts tab |
| `audit.view` | Audit route |
| `sites.view` | Sites route |
| `non_conformities.view` | Non-conformities route |
| `non_conformities.manage` | In-screen: create button, resolve action |
| `data_exports.manage` | Data exports route |
| `devices.view` | Devices list/detail routes |
| `devices.manage` | In-screen: device create/edit/delete, programme add/edit/delete |
| `products.view` | Products route |
| `products.manage` | In-screen: product create/edit/delete |
| `suppliers.view` | Suppliers route |
| `suppliers.manage` | In-screen: supplier create |
| `purchasing.view` | Purchases tab, purchase detail route |
| `purchasing.manage` | Goods receipt route |
| `patients.view` | Patients route |
| `patients.manage` | In-screen: patient create/edit/delete |
| `invitations.create` | In-screen: team invite button |
| `evidence_settings.manage` | DLU rules route (owner-only) |
| `prosthetic_cases.view` | Prosthetic tab, create/waiting-placement routes |
| `prosthetic_cases.manage` | Create + laboratories routes; in-screen: quick edit, status transitions |
| `prosthetic_payments.manage` | In-screen: payment section edit vs. read-only |

## Pilot Defaults

**TBD — needs product-owner input.** Which role(s) the pilot clinic's
actual users will be assigned isn't something this codebase or session
knows; it's a staffing/rollout decision. Once decided, this section
should list, per pilot user, their role and therefore exactly which tabs
and actions they'll see — the table above already answers "what does
role X get," this just needs the real mapping of *people* to *roles* for
this specific pilot.
