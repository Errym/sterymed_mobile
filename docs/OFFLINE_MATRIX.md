# Offline Matrix

What queues offline. What doesn't. The rule that decides.

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
| Label usage record | Write | QUEUE |
| Stock issue | Write | QUEUE |
| Stock adjust | Write | QUEUE |
| Stock transfer | Write | QUEUE |
| Goods receipt | Write | QUEUE |
| Cycle create | Write | QUEUE |
| Cycle start | Write | QUEUE |
| Cycle complete | Write | QUEUE |
| Cycle submit-for-release | Write | QUEUE |
| Cycle release | Write | QUEUE |
| Cycle item add | Write | QUEUE |
| Cycle item delete | Write | QUEUE |
| Cycle control test | Write | QUEUE |
| Cycle attachment upload | Write | QUEUE (photo bytes stored locally) |
| Cycle attachment delete | Write | QUEUE |
| Patient create | Write | QUEUE |
| Patient delete | Write | QUEUE |
| Product create | Write | QUEUE |
| Product delete | Write | QUEUE |
| Supplier create | Write | QUEUE |
| Purchase order create | Write | QUEUE |
| Prosthetic case create | Write | QUEUE (deferred — backend not shipped) |
| Prosthetic status change | Write | QUEUE (deferred) |
| Prosthetic payment | Write | QUEUE (deferred) |
| Search / filter | Read | NEVER |
| List fetch (first page) | Read | Cache 30-120s |
| List fetch (paginated) | Read | NEVER |
| Detail fetch | Read | Cache 60s |
| Dashboard fetch | Read | Cache 30s |
| Alerts fetch | Read | Cache 20s |

## Form state preservation

Every form that can be interrupted must persist its draft to Hive:

- Label usage form
- Cycle create form
- Cycle item add form
- Stock issue/adjust/transfer forms
- Patient create form
- Product create form
- Purchase order create form

On screen mount, restore. On submit success, clear.

## Sync engine behavior

- Triggered on: app start (if online), connectivity restore
- One item at a time, in creation order
- Max 5 retries per item, then move to manual review
- 409 → mark done (idempotency replay)
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
