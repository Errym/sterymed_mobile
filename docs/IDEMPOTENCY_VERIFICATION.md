# Idempotency-Key Verification

**Date:** 2026-09-29 23:35 UTC
**Backend:** `http://localhost:8010/api` (Docker Compose, host port 8010)
**Cycle tested:** `01a0de95-09f5-708b-b6e3-7060699ec3c2`

## The real contract (verified live)

**1. Key required on every POST.** Omitting it -> HTTP 400
`IDEMPOTENCY_KEY_REQUIRED`. Includes `POST /v1/auth/login`. The mobile
app's `IdempotencyInterceptor` sends one on every POST unconditionally -
the 2026-09-27 audit that removed the old path-whitelist is what keeps
login working at all today.

**2. Same key + same payload -> byte-identical replay.** Success responses
(200/201) have no `request_id`; the whole body is the fingerprint.
Error responses (4xx) carry the **same `request_id`** as the first call.

**3. Same key + DIFFERENT payload -> HTTP 409, new `request_id`.**
The backend **refuses** - it does not replay the original response, and
it does not apply the tampered payload. This is the defensive contract
`SyncEngine._syncOne()` already assumes: 409 -> `OutboxStatus.manualReview`.

## Result
PASS - idempotency contract holds

## Evidence
| Run | Key | Payload | HTTP | request_id | Body identical to run 1? |
|-----|-----|---------|------|------------|--------------------------|
| 1 | `6aa3c157-c5fe-417b-a908-755427418874` | original | 201 | `(none)` | - |
| 2 | `6aa3c157-c5fe-417b-a908-755427418874` | original | 201 | `(none)` | yes |
| 3 | `6aa3c157-c5fe-417b-a908-755427418874` | `{"tampered":true}` | 409 | `01a0ef86-45a0-70bc-a0d2-02ec802dffdb` | n/a (different payload -> 409, not replayed) |

- **Replay proof:** run 1 vs run 2 -> HTTP 201 vs 201, bodies identical
- **Defensive proof:** run 3 -> HTTP 409 (not 201, so the tampered payload was refused, not applied)

## Reproduce
```bash
cd ~/sterymed_mobile
python -m pip install requests   # once
python scripts/verify_idempotency.py
```

## Run 2 body (byte-identical replay of run 1)
```
{"id":"01a0de95-09f5-708b-b6e3-7060699ec3c2","device_id":"01a0d075-d371-71ce-8aa5-12cfdaa9ecd1","device_program_id":null,"operator_id":"01a0d920-d09f-707b-a64c-6764252a14d9","cycle_number":18,"status":"running","started_at":"2026-09-29T23:35:49+00:00","completed_at":null,"notes":null}
```
