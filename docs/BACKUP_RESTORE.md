# Backup & Restore

What lives on the device, what lives on the server, and exactly what
happens — and what is lost — when a user reinstalls the app.

## What mobile owns (device-local, never backed up by the app itself)

All of it lives in one of three Hive boxes or the platform secure-storage
keystore. Nothing here is synced to any backup service by the app; whether
the OS-level backup (iCloud/Android auto-backup) captures any of it
depends on device settings, not on anything this app configures.

| Store | Backing | Box/key | Contents |
|---|---|---|---|
| Outbox | Hive box | `steriymed.outbox` (`OutboxStore`, `lib/core/storage/outbox/outbox_store.dart`) | Queued offline writes: `labelUsage`, `stockIssue`, `stockAdjust`, `stockTransfer`, `goodsReceipt`, `cycleTransition` (`OutboxOperation`, `lib/core/storage/outbox/outbox_operation.dart`) — each item's `status` is one of `pending`, `syncing`, `synced`, `conflict`, `failed`, `manualReview` |
| Cycle notes cache | Hive box | `steriymed.cycle_notes` (`CycleNotesCache`, `lib/features/cycles/data/local/cycle_notes_cache.dart`) | Free-text cycle notes — see "The cycle-notes exception" below |
| KV store | Hive box | `steriymed.kv` (`KeyValueStore`, opened in `lib/di/storage_di.dart`) | Small local state, e.g. the prosthetic-case create-screen draft (`ProstheticCaseDraftStore`), onboarding-seen flag |
| Secure storage | OS keystore (`flutter_secure_storage`, `AndroidOptions(encryptedSharedPreferences: true)`) | `steriymed.bearer` (auth token), `steriymed.session.user`, `steriymed.session.tenant`, `steriymed.session.role` | Bearer token and cached session/tenant/role, used to skip re-login and to render the UI before the first `/me` refresh |
| In-memory cache | Plain `Map`, not persisted at all | `AppCache` (`lib/core/cache/cache.dart`) | Short-TTL (15s–5min) response caches for dashboard/alerts/cycles/stock/etc. — already gone on every cold start, reinstall or not |

## What mobile does NOT own

Every domain record — patients, cycles, stock levels, prosthetic cases,
non-conformities, alerts, audit events, purchase orders, devices,
laboratories, members, everything the UI lists or shows a detail screen
for — lives only on the backend (Postgres, in `steriqore`). The app never
holds a durable local copy of this data; `AppCache` entries expire in
seconds to minutes and are refetched, and there is no offline read
database. Losing the device loses zero server data.

## Recovery flow when the user reinstalls

1. Fresh install → all three Hive boxes and every secure-storage key are
   gone (both are app-scoped storage the OS deletes on uninstall).
2. User logs in again. `SessionStore.load()` finds nothing, so the app
   shows the login screen.
3. After login, `TokenStorage` gets a fresh bearer token and `SessionStore`
   re-populates from the real `/me`/login response — this is a normal
   login, not a "restore," because nothing about the account or its data
   was ever device-resident.
4. Every screen refetches from the backend as usual. From the server's
   point of view this is indistinguishable from a second device logging
   into the same account. No data migration or import step exists or is
   needed.

## Outbox contents survive reinstall? **NO.**

**Exact consequence:** any outbox item still in `pending`, `syncing`,
`failed`, or `manualReview` state at the moment of uninstall is
permanently and silently lost — there is no server-side mirror of a
queued-but-not-yet-synced write. Concretely, this means:

- A stock issue/adjust/transfer, label usage, goods receipt, or cycle
  transition that the user performed **while offline**, and that had not
  yet reached the server, never happens. The stock level, cycle state, or
  label usage the user believes they recorded is simply absent — with no
  error, because the app already showed a success snackbar for the
  synthetic offline result at the time it was queued (see
  `StockRepository._submitWrite`'s `synthetic(...)` return value).
- `manualReview` items are the worst case: these already failed to sync
  automatically and were waiting on the user to notice and resolve them
  (see the sync status UI, `SyncStatusCubit`). Reinstalling before
  resolving one discards it with no trace.
- **Mitigation today:** none beyond user process — tell the user not to
  uninstall/reinstall while `SyncStatusCubit`'s pending/failed count is
  non-zero. There is no cross-device outbox and no server-side staging
  endpoint to make this durable; that would require a backend change
  (accept a client-generated idempotency key ahead of the real write, or
  a dedicated pending-writes endpoint) that does not exist today.

## The cycle-notes exception

`CycleNotesCache` is not in the outbox at all and is never destined to
reach the server, reinstall or not: `PATCH /v1/cycles/{id}` does not exist
on the real backend (`BUG-007`), so cycle notes typed after creation are a
**device-only, permanently local** convenience by design, not a pending
sync. Reinstalling loses them the same way any Hive box loss does, but
unlike the outbox, there was never a "will this reach the server" window —
the answer was always no.

## Secure storage / KV store on reinstall

Losing the token and cached session on reinstall is expected and by
design (re-login) and not lossy on its own. Losing the KV store's
prosthetic-case create-screen draft (`ProstheticCaseDraftStore`) just
means an in-progress, not-yet-submitted draft has to be re-entered — the
same as it already is on force-quit, since that draft was never in the
outbox or synced anywhere either.
