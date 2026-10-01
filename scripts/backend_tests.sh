#!/usr/bin/env bash
# Run the steriqore (Laravel/Pest) tests in an ISOLATED container against a
# separate `steriqore_test` database. Needs the dev stack (`docker compose up`
# in the steriqore repo).
#
#   scripts/backend_tests.sh setup                 # once: DB + runner container
#   scripts/backend_tests.sh sync <file>...        # copy changed backend files in
#   scripts/backend_tests.sh run [pest args...]    # e.g. run tests/Feature/Api
#   scripts/backend_tests.sh teardown              # remove the runner container
#
# WHY NOT `docker exec steriqore-app php artisan test`: that container already
# exports DB_DATABASE=steriqore (the dev database), real environment variables
# win over phpunit.xml, and the suite uses RefreshDatabase, so it would WIPE
# the dev data. This script forces the separate steriqore_test database.
#
# Known baseline failures in this runner (not code bugs): the Web/* UI tests
# need a Vite build (public/build/manifest.json) and a few RLS tests need DB
# role grants that only exist in the full CI database.
set -euo pipefail

BACKEND="${STERIQORE_DIR:-$HOME/steriqore}"
RUNNER=steriqore-test-runner
NETWORK=steriqore_steriqore
IMAGE=steriqore-app
DB=steriqore_test

dx() { MSYS_NO_PATHCONV=1 docker exec "$@"; }

setup() {
  docker exec steriqore-postgres psql -U steriqore -d postgres -tc \
    "select 1 from pg_database where datname='$DB'" | grep -q 1 \
    || docker exec steriqore-postgres psql -U steriqore -d postgres -c "CREATE DATABASE $DB"
  docker rm -f "$RUNNER" >/dev/null 2>&1 || true
  MSYS_NO_PATHCONV=1 docker run -d --name "$RUNNER" --network "$NETWORK" \
    --entrypoint sleep "$IMAGE" infinity >/dev/null
  dx "$RUNNER" mkdir -p /work
  (cd "$BACKEND" && tar --exclude=.git --exclude=node_modules --exclude=vendor \
    --exclude=.env --exclude=storage/logs --exclude=public/build -cf - .) \
    | docker exec -i "$RUNNER" tar -xf - -C /work
  dx "$RUNNER" sh -c 'cd /work && cp .env.example .env \
    && php -r "copy(\"https://getcomposer.org/installer\", \"/tmp/cs.php\");" \
    && php /tmp/cs.php --quiet \
    && php composer.phar install --no-interaction --prefer-dist \
       --ignore-platform-req=ext-pcntl --ignore-platform-req=ext-posix \
       --ignore-platform-req=ext-exif --ignore-platform-req=ext-bcmath \
       --ignore-platform-req=ext-gd'
  echo "runner ready"
}

sync_files() {
  cd "$BACKEND"
  for f in "$@"; do
    dx "$RUNNER" mkdir -p "/work/$(dirname "$f")"
    MSYS_NO_PATHCONV=1 docker cp "$f" "$RUNNER:/work/$f"
  done
}

run() {
  dx \
    -e APP_ENV=testing -e DB_CONNECTION=pgsql -e DB_HOST=postgres -e DB_PORT=5432 \
    -e DB_DATABASE="$DB" -e DB_USERNAME=steriqore -e DB_PASSWORD=secret \
    -e CACHE_STORE=array -e APP_KEY=base64:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA= \
    "$RUNNER" sh -c "cd /work && php vendor/bin/pest $*"
}

case "${1:-}" in
  setup) setup ;;
  sync) shift; sync_files "$@" ;;
  run) shift; run "$@" ;;
  teardown) docker rm -f "$RUNNER" ;;
  *) sed -n '2,12p' "$0"; exit 1 ;;
esac
