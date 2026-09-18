# Backend Bugs — Blocking SteryMed Mobile

**Filed by:** Mobile engineer
**Date:** 2026-09-18
**Backend version:** `steriqore` @ commit `_____` (fill in)
**Staging URL:** `https://staging.example.com`

Every bug below has a `curl` reproduction and a suggested fix.

---

## BUG-001 — Attachment upload returns 500
**Severity:** 🔴 Blocking
**Endpoint:** `POST /api/v1/cycles/{cycle}/attachments`
**Called by:** `CycleAttachmentsScreen`

```bash
curl -X POST "https://staging.example.com/api/v1/cycles/{cycle_id}/attachments" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Idempotency-Key: test-$(date +%s)" \
  -F "file=@test.png"
```
**Expected:** 200 with `{id, url, file_name, mime_type, size, created_at}`.
**Actual:** 500 Internal Server Error.

---

## BUG-002 — Missing `GET /api/v1/locations`
**Severity:** 🔴 Blocking
**Called by:** `GoodsReceiptScreen`, `StockAdjustScreen`, `StockTransferScreen`
**Current workaround:** derived from `/stock-levels` (zero-stock locations missing).
**Expected:** `[{id, name, site_id}]`

---

## BUG-003 — Missing `GET /api/v1/batches`
**Severity:** 🔴 Blocking
**Called by:** Same as BUG-002.
**Expected:** `[{id, batch_number, product_id, product_name, expiry_date}]`

---

## BUG-004 — Missing `POST /api/v1/sites` and `POST /api/v1/locations`
**Severity:** 🟡 Non-blocking
**Impact:** Mobile cannot create a site. Feature is hidden.

---

## BUG-005 — Missing `PATCH /api/v1/patients/{id}`
**Severity:** 🔴 Blocking
**Called by:** `PatientFormSheet`
**Current workaround:** delete + recreate (data loss).
**Expected:** `PATCH /v1/patients/{id}` with partial body.

---

## BUG-006 — Missing `PATCH /api/v1/products/{id}`
**Severity:** 🔴 Blocking
**Called by:** `ProductFormSheet`
**Current workaround:** same as BUG-005.

---

## BUG-007 — Missing `PATCH /api/v1/cycles/{id}`
**Severity:** 🟡 Non-blocking
**Called by:** `CycleDetailScreen` (notes cached locally only).

---

## BUG-008 — `GET /api/v1/patients` returns only `{id, reference}`
**Severity:** 🔴 Blocking
**Called by:** `PatientListScreen`, `PatientPickerSheet`
**Impact:** Patients created elsewhere show without a name.

---

## Summary

| ID | Severity | Endpoint |
|----|----------|----------|
| BUG-001 | 🔴 | POST /cycles/{id}/attachments |
| BUG-002 | 🔴 | GET /locations |
| BUG-003 | 🔴 | GET /batches |
| BUG-004 | 🟡 | POST /sites, /locations |
| BUG-005 | 🔴 | PATCH /patients/{id} |
| BUG-006 | 🔴 | PATCH /products/{id} |
| BUG-007 | 🟡 | PATCH /cycles/{id} |
| BUG-008 | 🔴 | GET /patients (only id+ref) |
