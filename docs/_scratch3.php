<?php
require '/app/vendor/autoload.php';
$app = require '/app/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

use App\Domain\Tenancy\Models\Tenant;
use App\Support\Tenancy\TenantContext;
use Illuminate\Support\Facades\DB;

foreach (Tenant::all() as $t) {
    echo $t->slug . ' | ' . $t->id . PHP_EOL;
    $rows = DB::table('tenant_user')->where('tenant_id', $t->id)->get();
    foreach ($rows as $r) {
        echo '  pivot: ' . json_encode($r) . PHP_EOL;
    }
    TenantContext::run($t, function () use ($t) {
        foreach ($t->users as $u) {
            echo '  ' . $u->email . ' roles=' . json_encode($u->getRoleNames()) . PHP_EOL;
        }
    });
}
