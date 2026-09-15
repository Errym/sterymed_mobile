<?php
require '/app/vendor/autoload.php';
$app = require '/app/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

use App\Models\User;
use Illuminate\Support\Facades\Hash;

$u = User::where('email', 'test@test.com')->first();
$u->password = Hash::make('password123');
$u->save();
echo 'updated: ' . $u->email . PHP_EOL;
