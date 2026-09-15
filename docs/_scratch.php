<?php
require '/app/vendor/autoload.php';
$app = require '/app/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

use App\Domain\Tenancy\Models\Tenant;

foreach (Tenant::all() as $t) {
    echo $t->slug . ' | ' . $t->name . PHP_EOL;
    foreach ($t->users as $u) {
        $role = $u->pivot->role ?? ($u->role ?? '?');
        echo '  - ' . $u->email . ' (' . $role . ')' . PHP_EOL;
    }
}
