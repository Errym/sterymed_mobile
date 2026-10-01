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
| Prosthetic case create / status change / payment save | Write | ⚠️ NOT QUEUED — throws offline. See `docs/PROSTHETIC_MODULE.md`. This is a real, open gap now, not N/A. |
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

## Sync engine behavior (updated 2026-10-01)

Every queueable write is a **durable operation**: owner, Idempotency-Key and
the exact JSON body are saved *before* the first network byte, and the online
send and any later replay use that same record (`SyncEngine.submit`). One
serialized worker handles automatic flush, reconnect, resume and manual retry,
so two senders can never run at once. Duplicate taps share one operation, and a
second *different* action on a record that still has an unresolved operation is
refused (`operation_unresolved`).

| Outcome of a send | Item state | What happens next |
|---|---|---|
| 2xx with a record id | removed (confirmed), caches invalidated | none |
| 2xx but unreadable body | `unknownOutcome` | user checks the record |
| 401, or session not validated | `authBlocked` | resumes automatically after re-validation |
| 403 | `permissionDenied` | user can only **abandon** |
| 409 (key reused with different body, state conflict) | `conflict` | user can only **abandon** |
| 400/404/422 | `validationFailed` | user can only **abandon**, then re-enter corrected data |
| 429 (up to 5 tries) | `pending` with `Retry-After` | retried automatically, same key |
| timeout, dropped connection, 5xx, killed mid-send | `unknownOutcome` | never auto-resent; user chooses below |
| app restarted while `syncing` | `unknownOutcome` | same as above |
| older than 23 h after first attempt | `unknownOutcome` | **cannot be resent**; check the record, then abandon |

**Resolving a stuck item** (Sync queue screen). `unknownOutcome` inside the
23 h replay window offers **Renvoyer**: it re-sends with the *same key and
body*, so a server that already recorded the key replays its answer instead of
repeating the effect (residual risk: backend BD-08, a commit that failed to
record its key). Every stuck state offers **Abandonner**, which warns about the
loss and removes the item (never while it is being sent). Unresolved items stay
visible and block further actions on the same record until resolved.

The engine only runs for a validated session: nothing is queued or sent while
permissions are stale or the session is being replaced, and a response that
arrives after the session changed is never recorded against the new user.

Not covered: a normal online `POST` that is not queued (create product,
supplier, patient, prosthetic case...) gets a fresh key per submission and is
not retried automatically. If its response is lost, a manual second submit can
duplicate it unless the server enforces uniqueness.

## Verification

Every QUEUE row must be tested:
1. Turn airplane mode ON
2. Perform the action
3. Verify item appears in sync queue
4. Turn airplane mode OFF
5. Verify item syncs
6. Verify data appears on web

Log every test in `docs/DEVICE_TEST_LOG.md`.
