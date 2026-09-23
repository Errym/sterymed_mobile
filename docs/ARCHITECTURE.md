# Architecture

## Layering

```
lib/
├── core/        # Cross-cutting: no feature imports another feature directly
│   ├── cache/            # In-memory TTL cache (AppCache) — dashboard, lists
│   ├── config/           # Env (compile-time --dart-define), API endpoints, build info
│   ├── crash/            # CrashReporter (Sentry, PII-scrubbed)
│   ├── errors/            # ApiException, ErrorMapper (Dio → typed exceptions)
│   ├── network/          # Dio client + interceptors, CursorPage<T>
│   ├── permissions/      # Camera/notification OS permission wrappers
│   ├── router/           # AppRouter (go_router), RoleGuard, Routes/RouteNames
│   ├── storage/          # SecureStorage, TokenStorage, SessionStore, KeyValueStore,
│   │                     # outbox/ (OutboxStore, SyncEngine, OutboxItem/Operation/Status)
│   ├── sync/              # ConnectivityService, SyncStatusCubit
│   ├── theme/             # Design tokens (colors, spacing, typography)
│   └── utils/              # Debouncer, idempotency key generation, PII scrubber, logger
├── di/           # get_it service registration, split by concern
│                 # (core_di, network_di, storage_di, router_di, features_di)
├── features/     # One directory per domain feature (see below)
├── l10n/         # AppLocalizations (French only — see docs/LOCALIZATION.md)
└── shared/       # Reusable, feature-agnostic widgets (buttons, lists, feedback, layout)
```

## Per-feature structure

Every entry under `lib/features/` follows the same shape:

```
features/<name>/
├── data/
│   ├── datasources/    # Talks to Dio directly, maps JSON ↔ *Data models
│   ├── models/         # Plain data classes (Equatable), .fromJson factories
│   ├── local/          # Feature-local Hive/cache wrappers, if any (e.g. draft stores)
│   └── repositories/    # The only thing blocs talk to — owns caching, and for a
│                        # few features, the online-first/offline-outbox-fallback
│                        # pattern (see below)
└── presentation/
    ├── bloc/           # flutter_bloc State/Event/Bloc (or Cubit for simpler state)
    ├── screens/         # One StatelessWidget/StatefulWidget per route
    └── widgets/         # Feature-specific widgets not generic enough for shared/
```

Current features: `alerts`, `auth`, `catalog`, `compliance`, `cycles`,
`dashboard`, `devices`, `dlu`, `history`, `identity`, `labels`,
`patients`, `purchases`, `reporting`, `scanner`, `settings`, `shell`,
`sites`, `stock`, `suppliers`, `sync`. (No `prosthetic/` — removed per
`docs/adr/0010-prosthetic-deferred.md`.)

## The offline-fallback pattern

Four repositories (`LabelUsageRepository`, `CycleRepository`,
`PurchaseRepository`, `StockRepository`) implement the same shape for
their critical writes: check `ConnectivityService.isConnected` → if
online, try the real request, and on a network/timeout `ApiException`
fall through to the offline path; if offline (or just fell through),
enqueue an `OutboxItem` and return a synthetic result built from the
inputs already in hand. `docs/OFFLINE_MATRIX.md` lists exactly which
operations this covers — it's 6 operations
(`OutboxOperation`'s enum), not every write in the app.

## Routing and access control

`AppRouter` (go_router) has one `redirect` that checks
`RoleGuard.requiredPermissionFor(location)` against
`SessionStore.hasPermission()` before allowing navigation — permission-
based, reading whatever the backend actually granted this session, never
a hardcoded role check. See `docs/ROLE_MATRIX.md` for the full mapping.

## Dependency injection

`get_it`, registered at app start via `lib/di/di.dart`, split into
`core_di` (cache, logger, PII scrubber), `network_di` (Dio + interceptors),
`storage_di` (secure storage, session, outbox), `router_di`, and
`features_di` (one repository/datasource registration block per feature).
Screens and blocs pull dependencies via `getIt<T>()`, not constructor
injection through the widget tree, except where a bloc is provided via
`BlocProvider` for widget-tree-scoped state.
