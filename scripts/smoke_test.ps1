# SteryMed <-> steriqore -- live connectivity smoke test
#
# Logs into the running steriqore backend and hits every GET endpoint the
# mobile app consumes, printing HTTP status + row counts. Use it on
# delivery day to prove the app's backend is reachable and every route the
# app calls actually answers, before putting a phone in a clinician's hand.
#
# Usage (from repo root, with the steriqore docker stack up):
#   pwsh scripts/smoke_test.ps1
#   pwsh scripts/smoke_test.ps1 -BaseUrl http://localhost:8010 -Tenant demo2
#
# Exit code 0 = every checked endpoint returned 2xx. Non-zero = at least
# one failed (prints which). Read-only: it performs no writes.

param(
  [string]$BaseUrl  = "http://localhost:8010",
  [string]$Tenant   = "demo2",
  [string]$Email     = "admin2@steriqore.local",
  [string]$Password  = "password"
)

$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'SilentlyContinue'

$body = @{ email = $Email; password = $Password; tenant_slug = $Tenant } | ConvertTo-Json
$loginHeaders = @{ 'Idempotency-Key' = [guid]::NewGuid().ToString(); 'Accept' = 'application/json' }

Write-Host "== SteryMed connectivity smoke test =="
Write-Host "Backend: $BaseUrl   Tenant: $Tenant   User: $Email"
Write-Host ""

try {
  $login = Invoke-RestMethod -Uri "$BaseUrl/api/v1/auth/login" -Method Post -ContentType 'application/json' -Body $body -Headers $loginHeaders
} catch {
  Write-Host ("LOGIN FAILED: " + $_.Exception.Message)
  exit 2
}

Write-Host ("Login OK -- role: " + $login.user.role)
Write-Host ("Permissions granted: " + $login.user.permissions.Count)
Write-Host ""

$h = @{ 'Authorization' = ("Bearer " + $login.token); 'Accept' = 'application/json' }

$endpoints = @(
  'me', 'cycles', 'stock-levels', 'alerts', 'devices', 'products',
  'product-categories', 'suppliers', 'purchase-orders', 'patients',
  'prosthetic-cases', 'prosthetic-dashboard', 'prosthetic-cases/waiting-placement',
  'laboratories', 'audit-events', 'sites', 'dlu-rules', 'non-conformities',
  'members', 'data-export-requests', 'evidence-search'
)

$failures = 0
foreach ($p in $endpoints) {
  try {
    $r = Invoke-WebRequest -Uri "$BaseUrl/api/v1/$p" -Headers $h -Method Get -UseBasicParsing
    $j = $r.Content | ConvertFrom-Json
    if ($null -ne $j.data) { $count = $j.data.Count } elseif ($j -is [array]) { $count = $j.Count } else { $count = 'obj' }
    Write-Host ("  {0,-40} {1}  rows={2}" -f $p, $r.StatusCode, $count)
  } catch {
    $code = $_.Exception.Response.StatusCode.value__
    Write-Host ("  {0,-40} FAIL {1}" -f $p, $code)
    $failures = $failures + 1
  }
}

Write-Host ""
if ($failures -eq 0) {
  Write-Host ("All " + $endpoints.Count + " endpoints reachable and answering. [OK]")
  exit 0
}
Write-Host ("" + $failures + " endpoint(s) failed. [FAIL]")
exit 1
