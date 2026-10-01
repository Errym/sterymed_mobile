<?php

declare(strict_types=1);

require __DIR__.'/bootstrap.php';

use App\Domain\Identity\Actions\SeedTenantRolesAction;
use App\Domain\Tenancy\Models\Tenant;
use App\Models\User;
use App\Support\Tenancy\TenantContext;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\DB;

/** @return class-string<Model> */
function fixtureModel(string $name): string
{
    $domains = [
        'Tenancy' => ['Tenant', 'Site', 'Room', 'StorageLocation'], 'Identity' => ['TenantUser'],
        'Catalog' => ['Product'], 'Equipment' => ['Device', 'DeviceProgram'],
        'Purchasing' => ['Supplier', 'SupplierProduct', 'PurchaseOrder', 'PurchaseOrderLine', 'GoodsReceipt', 'GoodsReceiptLine'],
        'Inventory' => ['Batch', 'StockMovement', 'StockLevel', 'Alert'],
        'Sterilization' => ['Cycle', 'CycleItem', 'ControlTest', 'CycleRelease'],
        'Labeling' => ['DluRule', 'DluRuleVersion', 'LabelFormatVersion', 'Label', 'LabelPrint'], 'Traceability' => ['Patient', 'LabelUsage'],
        'Prosthetic' => ['Laboratory', 'ProstheticCase', 'ProstheticCaseStatusHistory'],
        'Compliance' => ['NonConformity', 'AuditEvent'],
    ];
    if ($name === 'User') {
        return User::class;
    }
    if ($name === 'Media') {
        return App\Support\Media\Media::class;
    }
    foreach ($domains as $domain => $models) {
        if (in_array($name, $models, true)) {
            return "App\\Domain\\{$domain}\\Models\\{$name}";
        }
    }
    throw new RuntimeException('Unknown fixture model: '.$name);
}

/** @param array<string, mixed> $row @param array<string, mixed> $settings */
function createFixtureRow(array $row, array $settings): void
{
    $class = fixtureModel($row['model']);
    $attributes = $row['attributes'];
    if ($row['model'] === 'User') {
        $attributes['password'] = $settings['password_hash'];
    }
    $model = new $class;
    $model->forceFill($attributes);
    $model->saveOrFail();
}

/** @param array<string, mixed> $blueprint @return array<string, mixed> */
function validatePersistedFixture(array $blueprint): array
{
    $counts = [];
    foreach (Tenant::all() as $tenant) {
        TenantContext::run($tenant, function () use ($tenant, $blueprint, &$counts): void {
            $expected = array_filter($blueprint['rows'], fn (array $row): bool => ($row['attributes']['tenant_id'] ?? null) === $tenant->id);
            foreach ($expected as $row) {
                $class = fixtureModel($row['model']);
                // withoutGlobalScopes includes intentionally archived rows;
                // PostgreSQL RLS still restricts this to the current tenant.
                if (! $class::withoutGlobalScopes()->whereKey($row['attributes']['id'])->exists()) {
                    throw new RuntimeException('Missing persisted fixture row: '.$row['key']);
                }
                $counts[$row['model']] = ($counts[$row['model']] ?? 0) + 1;
            }
            foreach ($blueprint['roles'] as $membership) {
                if ($membership['tenant_id'] === $tenant->id
                    && ! User::findOrFail($membership['user_id'])->hasRole($membership['role'])) {
                    throw new RuntimeException('Fixture role assignment missing.');
                }
            }
            $other = $blueprint['scenarios'][$tenant->slug === 'fixture-populated' ? 'empty.device' : 'populated.device'];
            if (App\Domain\Equipment\Models\Device::withoutGlobalScopes()->whereKey($other)->exists()) {
                throw new RuntimeException('RLS allowed a device from the other fixture tenant.');
            }
            $mismatch = DB::select('SELECT s.id FROM stock_levels s LEFT JOIN
                (SELECT batch_id, location_id, sum(qty) AS total FROM stock_movements GROUP BY batch_id, location_id) m
                ON m.batch_id=s.batch_id AND m.location_id=s.location_id WHERE s.quantity <> coalesce(m.total,0)');
            if ($mismatch !== []) {
                throw new RuntimeException('Fixture stock projection does not match the append-only ledger.');
            }
        });
    }
    if (Tenant::count() !== 2) {
        throw new RuntimeException('Expected exactly two synthetic tenants.');
    }

    return ['fixture_id' => FIXTURE_ID, 'executed' => true, 'validated_at' => gmdate(DATE_ATOM),
        'checks' => ['all_tenant_rows_present', 'all_role_assignments_present', 'cross_tenant_database_rls', 'stock_projection_matches_ledger'],
        'counts' => $counts];
}

try {
    $command = $argv[1] ?? '';
    if (! in_array($command, ['seed', 'reset', 'verify'], true)) {
        throw new RuntimeException('Only seed, reset and verify commands are supported.');
    }
    if ($command === 'reset' && ($argv[2] ?? '') !== FIXTURE_ID.':'.FIXTURE_DATABASE) {
        throw new RuntimeException('Reset identity confirmation is missing.');
    }
    $settings = fixtureSettings();
    $pdo = guardFixtureDatabase($settings, $command === 'seed');
    // Prevent concurrent seed/reset against the same dedicated database.
    if ((int) $pdo->query('SELECT pg_try_advisory_lock(180105466)::int')->fetchColumn() !== 1) {
        throw new RuntimeException('Another fixture mutation is running.');
    }
    $seeded = (int) $pdo->query('SELECT seeded::int FROM clinic_fixture_control.identity')->fetchColumn() === 1;
    if ($command === 'verify' && ! $seeded) {
        throw new RuntimeException('Fixture database has not completed seeding.');
    }
    if ($command === 'seed' && $seeded) {
        throw new RuntimeException('Fixture already seeded; use verify or explicit guarded reset.');
    }
    if ($command === 'reset') {
        // Fixed SQL identifiers, checked database owner, local ownership token,
        // marker and explicit identity confirmation: never an arbitrary DB.
        $pdo->beginTransaction();
        $pdo->exec('DROP SCHEMA public CASCADE');
        $pdo->exec('CREATE SCHEMA public AUTHORIZATION clinic_fixture_owner');
        $pdo->exec('UPDATE clinic_fixture_control.identity SET seeded=false');
        $pdo->commit();
    }
    $app = fixtureApplication($settings);
    $kernel = $app->make(Kernel::class);
    $kernel->bootstrap();
    $blueprint = json_decode(file_get_contents($settings['runtime'].'/blueprint.json'), true, flags: JSON_THROW_ON_ERROR);
    if ($command !== 'verify') {
        $pdo->exec('GRANT USAGE ON SCHEMA public TO clinic_fixture_app');
        $pdo->exec('ALTER DEFAULT PRIVILEGES FOR ROLE clinic_fixture_owner IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO clinic_fixture_app');
        $pdo->exec('ALTER DEFAULT PRIVILEGES FOR ROLE clinic_fixture_owner IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO clinic_fixture_app');
        if ($kernel->call('migrate', ['--database' => 'pgsql_admin', '--force' => true, '--no-interaction' => true]) !== 0) {
            throw new RuntimeException('Fixture migration failed: '.$kernel->output());
        }
        $settings['password_hash'] = password_hash($settings['fixture_password'], PASSWORD_BCRYPT, ['cost' => 10]);
        DB::transaction(function () use ($blueprint, $settings): void {
            foreach ($blueprint['rows'] as $row) {
                if (in_array($row['model'], ['Tenant', 'User'], true)) {
                    createFixtureRow($row, $settings);
                }
            }
            foreach (Tenant::all() as $tenant) {
                TenantContext::run($tenant, function () use ($blueprint, $settings, $tenant): void {
                    app(SeedTenantRolesAction::class)->execute($tenant);
                    foreach ($blueprint['rows'] as $row) {
                        if (($row['attributes']['tenant_id'] ?? null) === $tenant->id) {
                            createFixtureRow($row, $settings);
                        }
                    }
                    foreach ($blueprint['roles'] as $role) {
                        if ($role['tenant_id'] === $tenant->id) {
                            User::findOrFail($role['user_id'])->assignRole($role['role']);
                        }
                    }
                });
            }
        });
        foreach ($blueprint['attachments'] as $attachment) {
            if (! preg_match('#^[a-f0-9-]{36}/[a-z]+\.(png|pdf)$#D', $attachment['path'])) {
                throw new RuntimeException('Invalid fixture attachment path.');
            }
            $bytes = base64_decode($attachment['base64'], true);
            if ($bytes === false || ! hash_equals($attachment['sha256'], hash('sha256', $bytes))) {
                throw new RuntimeException('Fixture attachment checksum mismatch.');
            }
            $path = $settings['runtime'].'/media/'.$attachment['path'];
            if (! is_dir(dirname($path))) {
                mkdir(dirname($path), 0700, true);
            }
            file_put_contents($path, $bytes);
        }
    }
    $report = validatePersistedFixture($blueprint);
    file_put_contents($settings['runtime'].'/validation.json', json_encode($report, JSON_PRETTY_PRINT | JSON_THROW_ON_ERROR).PHP_EOL);
    if ($command !== 'verify') {
        $pdo->exec('UPDATE clinic_fixture_control.identity SET seeded=true');
    }
    fwrite(STDOUT, 'Fixture '.$command.' passed: two synthetic tenants, role assignments, RLS isolation and stock ledger verified.'.PHP_EOL);
} catch (Throwable $exception) {
    fwrite(STDERR, 'Fixture refused: '.$exception->getMessage().PHP_EOL);
    exit(2);
}
