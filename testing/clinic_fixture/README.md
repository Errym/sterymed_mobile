# Disposable clinic fixture

This kit creates synthetic data in a dedicated PostgreSQL 18 database. It is
Phase 0 infrastructure for acceptance tests; seeded records do not prove that
clinical workflows work. It never uses the demo tenant or a clinic database.

## What it covers

| Area | Starting states |
| --- | --- |
| Tenants | `fixture-populated` and `fixture-empty`; one shared account with different roles |
| Access | All six roles in both tenants; active and disabled membership, invited membership, globally disabled user |
| Pagination | 121 active patients, products, suppliers, batches, laboratories, purchase orders and prosthetic cases; over 121 cycles |
| Equipment | One active autoclave/program per tenant; archived device and storage location |
| First stock | Empty tenant has a site, two storage locations, product/supplier and ordered first purchase; zero batches/stock/cycles/patients/cases |
| Sterilization | Draft, running, completed, awaiting release, released, rejected; passed/failed control and immutable release rows |
| Labels | Created, printed, used with usage, used pending usage, expired, expires today, recalled, voided; release, DLU version and print-format references |
| Traceability | Pseudonymous patients, archived patient, label usage, recall/quarantine non-conformities, audit record |
| Purchasing | All six order states; partial/full receipts reconcile with lines and stock ledger |
| Prosthetic work | All six states, cancelled/restarted history, archived laboratory, unknown/partial/paid money, today/overdue/future appointments |
| Attachments | Distinct red/blue PNGs named `evidence.png` on one cycle; green PNG with same name on a prosthetic case; valid `ticket.pdf` |

The real membership schema has no archived field or supported archived
membership lifecycle. The kit uses disabled/invited membership and archived
domain records, rather than inventing a state the application does not support.

Entity IDs are deterministic UUIDv5 values. The actual model accepts supplied
UUIDs; production UUIDv7 generation is untouched. Dates are relative to
`--as-of`, so expiry and appointment cases remain reproducible. Recreate a
fixture with a current reference date when evaluating date-sensitive behavior.
The fixture does not freeze the server clock.

## Prepare and verify offline

From the mobile repository:

```powershell
python scripts/clinic_fixture.py self-test
python scripts/clinic_fixture.py prepare --backend C:/Users/mery/steriqore --as-of 2026-10-01
```

`prepare` makes no database or network connection. It copies an explicit
allowlist of backend source into ignored `build/clinic-fixture/backend`, records
source hashes, and generates a blueprint, local passwords and ownership token.
It excludes the original `.env`, dependencies, caches, uploads and logs. It
refuses an existing runtime instead of overwriting it. Nothing is written to the
source backend. All generated credentials stay under ignored `build/`.

## Provision the isolated runtime

Required: a working Docker daemon, PHP 8.4+ with `pdo_pgsql` and the backend's
Composer-required extensions, and Composer. Use the actual `composer.lock`.
No SQLite substitution is supported: this backend depends on PostgreSQL RLS,
`citext` and `uuidv7()`.

The following starts only the dedicated fixture Compose project. Inspect any
existing container/volume with these names before reusing it. The seeder also
checks ownership before any database mutation.

```powershell
docker compose --env-file build/clinic-fixture/compose.env -f testing/clinic_fixture/compose.yaml up -d --wait
composer install --working-dir=build/clinic-fixture/backend --no-interaction --prefer-dist --no-scripts
python scripts/clinic_fixture.py seed --php C:/tools/php85/php.exe
python scripts/clinic_fixture.py serve --php C:/tools/php85/php.exe
```

The local Composer wrapper requires PHP on its PATH; alternatively run the
Composer PHAR with the explicit PHP executable. Dependency installation stays
inside the isolated backend copy. `--no-scripts` avoids the source project's
post-install commands; Laravel discovers packages in the fixture runtime when
bootstrapped. Do not copy a production `.env` or existing database into it.

`seed` migrates the isolated database, creates records through the actual
Eloquent models and tenant context, assigns roles using the actual role seeder,
and verifies persisted rows, roles, RLS tenant isolation and stock ledger totals.
It only exports these files after those checks pass:

- `build/clinic-fixture/manifest.json`: scenario IDs and synthetic email addresses.
- `build/clinic-fixture/validation.json`: checks that actually executed.
- `build/clinic-fixture/flutter_defines.json`: desktop/iOS simulator/Android `adb reverse` config.
- `build/clinic-fixture/flutter_defines.android_emulator.json`: Android emulator host alias.

`GET http://127.0.0.1:18010/__clinic_fixture` returns the fixture ID, database
name, tenant IDs and device IDs after the server verifies the database marker.
It contains no secrets. Integration tests must check this marker before login
or mutation. `API_BASE_URL` is `/api`; the mobile endpoint builder adds `/v1`.

Use a fresh test installation of the mobile app so cached tenant data and
offline queues belong to this fixture. The launcher does not erase an existing
installation. Physical Android devices can use `adb reverse tcp:18010 tcp:18010`
and the loopback defines; the server intentionally does not bind the LAN.

Example after the fixture is serving:

```powershell
flutter test integration_test/journeys/cycle_lifecycle_journey_test.dart --dart-define-from-file=build/clinic-fixture/flutter_defines.json
```

Select an actual supported test device with `-d` when required by Flutter.
Fixture creation and API marker success do not constitute mobile acceptance.

## Reset safely

Stop the fixture server and test clients first, then:

```powershell
python scripts/clinic_fixture.py reset --php C:/tools/php85/php.exe --confirm sterymed-clinic-fixture-v1:steriqore_mobile_fixture
python scripts/clinic_fixture.py verify --php C:/tools/php85/php.exe
```

Reset uses fixed SQL identifiers. It verifies loopback port 5466, database name,
database owner, restricted application role, a fixture marker, its local random
ownership token and the exact blueprint hash before dropping the fixture's
`public` schema. The separate control schema survives. Reset remigrates/reseeds
the same blueprint and returns the same IDs. It never drops a database, accepts
an arbitrary database name, or truncates an existing clinic/test database.

An unmarked database can be claimed only if its public schema contains no
objects/functions and it has no other user schemas. A nonempty unmarked
database is always refused. The running app uses `clinic_fixture_app`
(no superuser, bypass-RLS, create-role, create-DB or inherited owner privilege).
Only migrations/reset use `clinic_fixture_owner`. A PostgreSQL advisory lock
prevents simultaneous seed/reset processes. The marker is checked on every
served request. Mail uses the array transport; disk storage, cache and logs are
local; queues are synchronous and telemetry is disabled.

Reset intentionally leaves fixture media files on disk; it rewrites the known
deterministic attachment paths. No recursive file deletion is performed.
Uploaded test files can be removed later with the entire disposable runtime
after checking its resolved path. Do not remove the local ownership token and
then try to claim an existing database.

## Current execution evidence

The offline fixture/guard/source-contract tests pass. PHP 8.5.11 at
`C:/tools/php85/php.exe` linted all three PHP files successfully. The isolated
database has **not** been seeded or validated in this environment: Docker
Desktop reports it is unable to start, and backend Composer dependencies are
absent. Consequently no live fixture manifest/Flutter defines are advertised as
ready and no clinic acceptance result is claimed.

Laravel configuration isolation and local signed media serving follow the
[Laravel configuration documentation](https://laravel.com/docs/13.x/configuration)
and [filesystem documentation](https://laravel.com/docs/13.x/filesystem).
The source-contract test checks fixture attributes and enum values against the
reviewed sibling backend. PHP lint checks syntax only; migrations, actual
relations, package behavior, private media URLs and real requests still require
the isolated runtime checks above.
