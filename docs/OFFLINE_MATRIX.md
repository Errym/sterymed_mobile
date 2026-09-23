# Offline Matrix

What queues offline. What doesn't. The rule that decides.

**Audited 2026-09-23 against the actual code** (`lib/core/storage/outbox/outbox_operation.dart`
is the source of truth: only 6 operations exist —  `labelUsage`, `stockIssue`,
`stockAdjust`, `stockTransfer`, `goodsReceipt`, `cycleTransition`). The table
below previously claimed 13 more write actions queued offline; they don't —
those repository methods call the remote datasource directly and throw if
there's no connection. Fixed here; the gap itself (whether to build that
wiring) is a separate, unstarted decision, not a doc problem.

## Rule

A **write** operation (POST/PATCH/DELETE) queues if:
- It represents real work a nurse/assistant is doing now
- It is idempotent by design (has an Idempotency-Key)
- The user cannot reasonably be asked to "wait until you have internet"

A **read** operation (GET) queues only if it's already been fetched once and we can serve from cache.

## Matrix

| Action | Type | Offline behavior |
|---|---|---|
| Label scan lookup | Read | NEVER — cache last 50 for offline lookup |
| Label usage record | Write | **QUEUE** (`labelUsage`) |
| Stock issue | Write | **QUEUE** (`stockIssue`) |
| Stock adjust | Write | **QUEUE** (`stockAdjust`) |
| Stock transfer | Write | **QUEUE** (`stockTransfer`) |
| Goods receipt | Write | **QUEUE** (`goodsReceipt`) |
| Cycle start | Write | **QUEUE** (`cycleTransition`) |
| Cycle complete | Write | **QUEUE** (`cycleTransition`) |
| Cycle submit-for-release | Write | **QUEUE** (`cycleTransition`) |
| Cycle release | Write | **QUEUE** (`cycleTransition`) |
| Cycle create | Write | ⚠️ NOT QUEUED — throws offline (`CycleRepository.create`) |
| Cycle item add / delete | Write | ⚠️ NOT QUEUED — throws offline |
| Cycle control test | Write | ⚠️ NOT QUEUED — throws offline |
| Cycle attachment upload / delete | Write | ⚠️ NOT QUEUED, and the screen itself is disabled pending `docs/BACKEND_BUGS.md#bug-001` |
| Patient create / delete | Write | ⚠️ NOT QUEUED — throws offline |
| Product create / delete | Write | ⚠️ NOT QUEUED — throws offline |
| Supplier create | Write | ⚠️ NOT QUEUED — throws offline |
| Purchase order create | Write | ⚠️ NOT QUEUED — throws offline (only *receiving* an existing PO queues) |
| ~~Prosthetic case create/status/payment~~ | — | N/A — module deleted, see ADR-0010. Not a gap to close. |
| Search / filter | Read | NEVER |
| List fetch (first page) | Read | Cache 30-120s |
| List fetch (paginated) | Read | NEVER |
| Detail fetch | Read | Cache 60s |
| Dashboard fetch | Read | Cache 30s |
| Alerts fetch | Read | Cache 20s |

## Form state preservation

The intent: every form that can be interrupted mid-fill should persist its
draft to Hive, restore on screen mount, and clear on submit success. Built
so far:

- **Label usage form** — the only one implemented
  (`LabelUsageDraftStore`), because it was the one explicitly audited and
  found to lose all input if the app was killed mid-form. The rest (cycle
  create, cycle item add, stock issue/adjust/transfer, patient create,
  product create, purchase order create) don't have this yet — an
  unstarted gap, not a doc error, but don't assume they're covered.

## Sync engine behavior

- Triggered on: app start (if online), connectivity restore
- One item at a time, in creation order
- A **benign replay** (same Idempotency-Key, same payload) never reaches
  an error branch at all — the backend's `EnsureIdempotency` middleware
  returns the *original* response verbatim at its original 2xx status,
  which the sync engine treats as a normal success.
- 409 (`IDEMPOTENCY_KEY_REUSED`) → **manual review, not auto-removed**.
  This only fires when the same key is reused with a *different* payload
  — a genuine anomaly that should never happen with per-item UUID v4
  keys, and treating it as "already synced" would silently drop data.
  (Was implemented the wrong way — auto-discarding on 409 — until this
  was found and fixed; see `docs/DAILY_LOG.md`'s Phase 5 entry and
  `test/unit/storage/sync_engine_test.dart`.)
- 422/403 → move to manual review
- 5xx/network → retry with backoff

## Verification

Every QUEUE row must be tested:
1. Turn airplane mode ON
2. Perform the action
3. Verify item appears in sync queue
4. Turn airplane mode OFF
5. Verify item syncs
6. Verify data appears on web

Log every test in `docs/DEVICE_TEST_LOG.md`.
