# Role Matrix

**Captured:** 2026-09-19T22:09:53Z
**Backend:** http://localhost:8010/api
**Admin:** admin2@steriqore.local
**Staff:** staff2@steriqore.local

| Endpoint | Admin | Staff |
|---|---|---|
| `/v1/me` | 200 | 200 |
| `/v1/alerts` | 200 | 403 |
| `/v1/audit-events` | 200 | 403 |
| `/v1/cycles` | 200 | 403 |
| `/v1/stock-levels` | 200 | 403 |
| `/v1/products` | 200 | 403 |
| `/v1/product-categories` | 200 | 403 |
| `/v1/suppliers` | 200 | 403 |
| `/v1/purchase-orders` | 200 | 403 |
| `/v1/patients` | 200 | 403 |
| `/v1/sites` | 200 | 403 |
| `/v1/devices` | 200 | 403 |
| `/v1/dlu-rules` | 200 | 403 |
| `/v1/non-conformities` | 200 | 403 |
| `/v1/data-export-requests` | 200 | 403 |
| `/v1/evidence-search` | 200 | 403 |
| `/v1/members` | 404 | 404 |
