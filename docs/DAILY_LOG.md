# Daily Log — SteryMed Mobile

## Template

### YYYY-MM-DD — Phase X Day Y

**Done today:**
-

**Blocked on:**
-

**Next:**
-

**Answers from stakeholders:**
-

---

## Entries

## Idempotency Test Deferred

Attempted to capture real 409 on `/v1/stock-movements/adjust`. The endpoint rejects our seeded data with 422 VALIDATION_FAILED, so the request never reaches the idempotency layer.

**Root cause:** The batch/location seeded via tinker doesn't satisfy the adjustment's business rules (likely requires a receipt, or a specific stock state).

**Decision:** Defer real 409 capture to Phase 3, when the offline sync engine will test idempotency against real data flows.

The `IdempotencyInterceptor` in code is already correct — it injects a UUID v4 into every queuable POST. Phase 3 will verify the backend honors it.
