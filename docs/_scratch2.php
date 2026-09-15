<?php
require '/app/vendor/autoload.php';
$app = require '/app/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

use App\Domain\Tenancy\Models\Tenant;
use Illuminate\Support\Facades\DB;

foreach (Tenant::all() as $t) {
    echo $t->slug . ' | ' . $t->id . PHP_EOL;
    $rows = DB::table('tenant_users')->where('tenant_id', $t->id)->get();
    foreach ($rows as $r) {
        echo '  ' . json_encode($r) . PHP_EOL;
    }
}
