# Missing Features & Workarounds

**Last updated:** 2026-09-18

| # | Feature | Why | Priority |
|---|---------|-----|----------|
| 1 | Patient edit | No `PATCH /v1/patients/{id}` | 🔴 |
| 2 | Product edit | No `PATCH /v1/products/{id}` | 🔴 |
| 3 | Cycle notes | No `PATCH /v1/cycles/{id}` | 🟡 |
| 4 | Patient names | `GET /v1/patients` returns only `{id, reference}` | 🔴 |
| 5 | Locations | No `GET /v1/locations` | 🟡 |
| 6 | Batches | No `GET /v1/batches` | 🟡 |
| 7 | Site creation | No `POST /v1/sites` | 🟢 |
| 8 | Attachments | Backend returns 500 | 🔴 |
| 9 | Prosthetic | Backend domain does not exist | 🔴 |

Each is documented in `BACKEND_BUGS.md` with a curl reproduction.
