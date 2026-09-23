# Role Matrix

**Rewritten 2026-09-23.** The previous version of this file ("Admin +
Staff only", captured 2026-09-19 against two test accounts) described an
early planning assumption, not the actual model. It's wrong: the backend
seeds **six** roles per tenant (`steriqore`'s `SeedTenantRolesAction`),
and this app was deliberately built **permission-based, not role-based**
— it never checks "is this user admin or staff," it checks "does this
user have `cycles.release`." That design decision stays; this doc now
describes it accurately instead of the two-role assumption.

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

25 of the 33 backend permissions are checked somewhere in this codebase
(route guard or in-screen action gate). The other 8
(`invitations.revoke`, `memberships.disable`, `sites.manage`,
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

## Pilot Defaults

**TBD — needs product-owner input.** Which role(s) the pilot clinic's
actual users will be assigned isn't something this codebase or session
knows; it's a staffing/rollout decision. Once decided, this section
should list, per pilot user, their role and therefore exactly which tabs
and actions they'll see — the table above already answers "what does
role X get," this just needs the real mapping of *people* to *roles* for
this specific pilot.
