<?php

declare(strict_types=1);

// This file lives in the MOBILE repo. It never loads the original backend .env.
const FIXTURE_ID = 'sterymed-clinic-fixture-v1';
const FIXTURE_DATABASE = 'steriqore_mobile_fixture';
const FIXTURE_OWNER = 'clinic_fixture_owner';
const FIXTURE_APP = 'clinic_fixture_app';

/** @return array<string, mixed> */
function fixtureSettings(): array
{
    $runtime = realpath(dirname(__DIR__, 2).'/build/clinic-fixture');
    $path = getenv('CLINIC_FIXTURE_SETTINGS');
    if ($runtime === false || ! is_string($path) || realpath($path) !== $runtime.DIRECTORY_SEPARATOR.'settings.json') {
        throw new RuntimeException('Refusing settings outside the dedicated fixture runtime.');
    }
    $settings = json_decode(file_get_contents($path), true, flags: JSON_THROW_ON_ERROR);
    $database = $settings['database'] ?? [];
    if (($settings['fixture_id'] ?? null) !== FIXTURE_ID
        || ($settings['purpose'] ?? null) !== 'disposable-synthetic-clinic'
        || realpath($settings['runtime'] ?? '') !== $runtime
        || realpath($settings['backend'] ?? '') !== $runtime.DIRECTORY_SEPARATOR.'backend'
        || ($settings['api_url'] ?? null) !== 'http://127.0.0.1:18010/api'
        || ($database['host'] ?? null) !== '127.0.0.1'
        || ($database['port'] ?? null) !== 5466
        || ($database['database'] ?? null) !== FIXTURE_DATABASE
        || ($database['owner'] ?? null) !== FIXTURE_OWNER
        || ($database['username'] ?? null) !== FIXTURE_APP
        || strlen($settings['owner_token'] ?? '') < 32) {
        throw new RuntimeException('Fixture identity, endpoint or ownership settings mismatch.');
    }
    if (! hash_equals($settings['blueprint_sha256'], hash_file('sha256', $runtime.'/blueprint.json'))) {
        throw new RuntimeException('Fixture blueprint changed after preparation.');
    }

    return $settings;
}

/** @param array<string, mixed> $settings */
function fixturePdo(array $settings, bool $owner): PDO
{
    $db = $settings['database'];

    return new PDO('pgsql:host=127.0.0.1;port=5466;dbname='.FIXTURE_DATABASE.';connect_timeout=5',
        $owner ? FIXTURE_OWNER : FIXTURE_APP, $owner ? $db['owner_password'] : $db['password'],
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
}

/**
 * Verify identities BEFORE Laravel boot or any mutation. A fresh unmarked
 * database may be claimed only when no user objects or schemas exist.
 * The control schema survives reset and is inaccessible to the application.
 *
 * @param array<string, mixed> $settings
 */
function guardFixtureDatabase(array $settings, bool $claim = false): PDO
{
    $pdo = fixturePdo($settings, true);
    $identity = $pdo->query("select current_database() as database, current_user as role,
        pg_get_userbyid(datdba) as owner, current_setting('server_version_num')::int as version
        from pg_database where datname = current_database()")->fetch(PDO::FETCH_ASSOC);
    if ($identity['database'] !== FIXTURE_DATABASE || $identity['role'] !== FIXTURE_OWNER
        || $identity['owner'] !== FIXTURE_OWNER || (int) $identity['version'] < 180000) {
        throw new RuntimeException('Database identity/owner/PostgreSQL 18 requirement failed.');
    }
    $appPdo = fixturePdo($settings, false);
    $appRole = $appPdo->query("select current_database() as database, current_user as role,
        (rolsuper or rolbypassrls or rolcreatedb or rolcreaterole
         or pg_has_role(current_user, 'clinic_fixture_owner', 'MEMBER'))::int as elevated
        from pg_roles where rolname = current_user")->fetch(PDO::FETCH_ASSOC);
    if ($appRole['database'] !== FIXTURE_DATABASE || $appRole['role'] !== FIXTURE_APP || (int) $appRole['elevated'] !== 0) {
        throw new RuntimeException('Fixture app role must be restricted and cannot inherit owner privileges.');
    }
    $hasMarker = (int) $pdo->query("select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace
        where n.nspname='clinic_fixture_control' and c.relname='identity' and c.relkind='r'")->fetchColumn() === 1;
    if (! $hasMarker) {
        $objects = (int) $pdo->query("select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace
            where n.nspname='public'")->fetchColumn();
        $functions = (int) $pdo->query("select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
            where n.nspname='public'")->fetchColumn();
        $schemas = (int) $pdo->query("select count(*) from pg_namespace
            where nspname not in ('public','information_schema') and nspname not like 'pg_%'")->fetchColumn();
        if (! $claim || $objects !== 0 || $functions !== 0 || $schemas !== 0) {
            throw new RuntimeException('Unmarked or nonempty database: never claim existing clinic/test data.');
        }
        $pdo->beginTransaction();
        $pdo->exec('CREATE SCHEMA clinic_fixture_control AUTHORIZATION clinic_fixture_owner');
        $pdo->exec('REVOKE ALL ON SCHEMA clinic_fixture_control FROM PUBLIC');
        $pdo->exec('CREATE TABLE clinic_fixture_control.identity (singleton boolean PRIMARY KEY CHECK(singleton),
            fixture_id text NOT NULL, owner_token text NOT NULL, blueprint_sha256 text NOT NULL, seeded boolean NOT NULL DEFAULT false)');
        $statement = $pdo->prepare('INSERT INTO clinic_fixture_control.identity VALUES (true, ?, ?, ?, false)');
        $statement->execute([FIXTURE_ID, $settings['owner_token'], $settings['blueprint_sha256']]);
        $pdo->commit();
    }
    $marker = $pdo->query('SELECT * FROM clinic_fixture_control.identity')->fetchAll(PDO::FETCH_ASSOC);
    if (count($marker) !== 1 || $marker[0]['fixture_id'] !== FIXTURE_ID
        || ! hash_equals($settings['owner_token'], $marker[0]['owner_token'])
        || ! hash_equals($settings['blueprint_sha256'], $marker[0]['blueprint_sha256'])) {
        throw new RuntimeException('Database fixture marker does not match the local ownership token and blueprint.');
    }

    return $pdo;
}

/** @param array<string, mixed> $settings */
function fixtureApplication(array $settings): Illuminate\Foundation\Application
{
    $runtime = $settings['runtime'];
    $backend = $settings['backend'];
    // Set cache paths before Application is constructed. Existing deployment
    // caches and the source .env cannot affect this isolated application.
    foreach ([
        'APP_ENV' => 'testing', 'APP_DEBUG' => 'false',
        'APP_CONFIG_CACHE' => $runtime.'/bootstrap-config.php',
        'APP_ROUTES_CACHE' => $runtime.'/bootstrap-routes.php',
        'APP_EVENTS_CACHE' => $runtime.'/bootstrap-events.php',
        'APP_SERVICES_CACHE' => $runtime.'/bootstrap-services.php',
        'APP_PACKAGES_CACHE' => $runtime.'/bootstrap-packages.php',
        'SENTRY_LARAVEL_DSN' => '', 'SENTRY_DSN' => '',
        'NIGHTWATCH_ENABLED' => 'false', 'PULSE_ENABLED' => 'false', 'TELESCOPE_ENABLED' => 'false',
    ] as $key => $value) {
        putenv($key.'='.$value);
        $_ENV[$key] = $value;
        $_SERVER[$key] = $value;
    }
    if (is_file($runtime.'/bootstrap-config.php') || is_file($runtime.'/bootstrap-routes.php')) {
        throw new RuntimeException('Fixture runtime must not use cached configuration or routes.');
    }
    require $backend.'/vendor/autoload.php';
    $app = require $backend.'/bootstrap/app.php';
    $app->useEnvironmentPath($runtime);
    $app->loadEnvironmentFrom('.env.fixture');
    $app->useStoragePath($runtime.'/storage');
    $app->afterBootstrapping(Illuminate\Foundation\Bootstrap\LoadConfiguration::class, function ($app) use ($settings, $runtime): void {
        $db = $settings['database'];
        $connection = ['driver' => 'pgsql', 'host' => '127.0.0.1', 'port' => 5466,
            'database' => FIXTURE_DATABASE, 'username' => FIXTURE_APP, 'password' => $db['password'],
            'charset' => 'utf8', 'prefix' => '', 'search_path' => 'public', 'sslmode' => 'disable'];
        $local = ['driver' => 'local', 'root' => $runtime.'/media', 'serve' => true, 'throw' => true];
        $app['config']->set([
            'app.env' => 'testing', 'app.debug' => false, 'app.key' => $settings['app_key'],
            'app.url' => 'http://127.0.0.1:18010', 'app.timezone' => 'Europe/Paris',
            'database.default' => 'pgsql', 'database.connections' => [
                'pgsql' => $connection,
                'pgsql_admin' => [...$connection, 'username' => FIXTURE_OWNER, 'password' => $db['owner_password']],
            ],
            'database.redis' => [], 'cache.default' => 'file',
            'cache.stores.file' => ['driver' => 'file', 'path' => $runtime.'/storage/framework/cache/data'],
            'session.driver' => 'array', 'queue.default' => 'sync',
            'mail.default' => 'array', 'mail.mailers.array' => ['transport' => 'array'],
            'logging.default' => 'single', 'logging.channels.single' => ['driver' => 'single', 'path' => $runtime.'/storage/logs/fixture.log', 'level' => 'debug'],
            'filesystems.default' => 'media', 'filesystems.disks' => ['media' => $local, 'local' => $local, 'backups' => [...$local, 'root' => $runtime.'/backups']],
            'media-library.disk_name' => 'media', 'media-library.queue_conversions_by_default' => false,
            'sentry.dsn' => null, 'nightwatch.enabled' => false, 'pulse.enabled' => false, 'telescope.enabled' => false,
        ]);
    });

    return $app;
}
