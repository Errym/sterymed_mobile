<?php

declare(strict_types=1);

require __DIR__.'/bootstrap.php';

try {
    $settings = fixtureSettings();
    $pdo = guardFixtureDatabase($settings);
    if ((int) $pdo->query('SELECT seeded::int FROM clinic_fixture_control.identity')->fetchColumn() !== 1) {
        throw new RuntimeException('Fixture is not seeded.');
    }
    $path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
    if ($path === '/__clinic_fixture') {
        header('Content-Type: application/json');
        header('Cache-Control: no-store');
        if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
            http_response_code(405);
            echo '{"error":"GET required"}';
            return;
        }
        $blueprint = json_decode(file_get_contents($settings['runtime'].'/blueprint.json'), true, flags: JSON_THROW_ON_ERROR);
        echo json_encode(['fixture_id' => FIXTURE_ID, 'database' => FIXTURE_DATABASE,
            'tenant_ids' => [$blueprint['scenarios']['populated.tenant'], $blueprint['scenarios']['empty.tenant']],
            'device_ids' => [$blueprint['scenarios']['populated.device'], $blueprint['scenarios']['empty.device']],
        ], JSON_THROW_ON_ERROR);
        return;
    }
    // This server exposes API and private signed media routes only. Static
    // files, original public assets, settings and source cannot be downloaded.
    if (! str_starts_with($path, '/api/') && ! str_starts_with($path, '/storage/')) {
        http_response_code(404);
        return;
    }
    $app = fixtureApplication($settings);
    $app->handleRequest(Illuminate\Http\Request::capture());
} catch (Throwable $exception) {
    http_response_code(503);
    header('Content-Type: application/json');
    echo '{"error":"Fixture environment unavailable; inspect local fixture logs"}';
    error_log($exception->getMessage());
}
