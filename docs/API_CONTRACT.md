# SteryMed Mobile — API Contract

**Frozen:** 2026-09-22
**Backend commit:** `steriqore` @ `6af6b9c` (verified against live OpenAPI spec, local docker instance, port 8010)
**Staging URL:** http://localhost:8010 (local dev; no staging deployment exists yet)
**Frozen by:** Mobile engineer
**Signed off by:** _pending web/backend engineer sign-off_

Any change to this contract after freeze requires a written change request.

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
19. Prosthetic (N/A — see ADR 0010)

---

## 1. Conventions

### Base URL
`https://staging.steriqore.example.com/api`

### Headers

| Header | Required on | Value |
|---|---|---|
| `Authorization` | All authenticated endpoints | `Bearer <token>` |
| `Idempotency-Key` | All POST/PATCH/DELETE | UUID v4 |
| `Accept` | Always | `application/json` |
| `Content-Type` | POST/PATCH with body | `application/json` or `multipart/form-data` |

### Response envelope

**Success (single resource):**
```json
{ ...resource fields... }