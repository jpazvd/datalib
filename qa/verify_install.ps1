<#
.SYNOPSIS
    Acceptance test for datalib: install the package, then use it as a user would.

.DESCRIPTION
    Runs qa/verify_install.do from a scratch working directory so that nothing
    resolves out of the repo's src/ tree by accident.

    Run this from the repo root; it changes to a scratch directory itself
    before invoking Stata. Full write-up: the "Verify your install" section
    of the top-level README.

.PARAMETER Stata
    Path to the Stata executable. Defaults to Stata 17 MP in the usual location.

.EXAMPLE
    powershell -File qa/verify_install.ps1
    powershell -File qa/verify_install.ps1 -Stata "C:\Program Files\Stata18\StataSE-64.exe"
#>
[CmdletBinding()]
param(
    [string]$Stata = "C:\Program Files\Stata17\StataMP-64.exe"
)

$ErrorActionPreference = "Stop"

# Repo root = parent of this script's directory.
$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$repoFwd = $repo -replace '\\', '/'

Write-Host "datalib acceptance test" -ForegroundColor Cyan
Write-Host "  repo : $repo"
Write-Host "  stata: $Stata"

if (-not (Test-Path $Stata)) {
    Write-Host ""
    Write-Host "Stata not found at: $Stata" -ForegroundColor Red
    Write-Host "Pass the right path, e.g.:" -ForegroundColor Yellow
    Write-Host '  powershell -File qa/verify_install.ps1 -Stata "C:\Program Files\Stata18\StataSE-64.exe"'
    exit 2
}
if (-not (Test-Path (Join-Path $repo "datalib.pkg"))) {
    Write-Host "No datalib.pkg at $repo - is this the repo root?" -ForegroundColor Red
    exit 2
}

# Run from a scratch cwd. Stata puts "." on the adopath, so running from the
# repo root would risk resolving code out of the working tree and quietly
# defeat the point of the test.
$work = Join-Path ([System.IO.Path]::GetTempPath()) "datalib_verify_run"
if (Test-Path $work) { Remove-Item -Recurse -Force $work }
New-Item -ItemType Directory -Force -Path $work | Out-Null

# Shadow the operator's startup profile. Stata runs the first profile.do it
# finds on the ado-path, and "." precedes PERSONAL, so an empty one here means
# the acceptance test is isolated from machine config in the same way it is
# already isolated from the repo's src/ tree. This is not cosmetic: a startup
# profile that probes a network drive or waits on a dialog blocks -stata -b-
# before the do-file is ever reached, and the run dies at the timeout below
# with no log to explain why.
Set-Content -Path (Join-Path $work "profile.do") -Encoding utf8 `
    -Value "* intentionally empty: isolates the acceptance test from the operator's startup profile"

# Clear any install root left by a previous run, so V2 tests a fresh install.
$instRoot = Join-Path ([System.IO.Path]::GetTempPath()) "datalib_verify_ado"
if (Test-Path $instRoot) { Remove-Item -Recurse -Force $instRoot }

$log = Join-Path $repo "qa\logs\verify_install.log"
if (Test-Path $log) { Remove-Item -Force $log }

Push-Location $work
try {
    $p = Start-Process -FilePath $Stata `
        -ArgumentList "-b", "do", "`"$repoFwd/qa/verify_install.do`"", "`"$repoFwd`"" `
        -PassThru -NoNewWindow
    # Stata batch mode on Windows does not always terminate on its own even
    # after -exit-, so bound the wait and read the verdict from the log.
    if (-not $p.WaitForExit(300000)) { $p.Kill() }
}
finally {
    Pop-Location
}

if (-not (Test-Path $log)) {
    Write-Host "No log produced - Stata failed to start the do-file." -ForegroundColor Red
    exit 2
}

$pass = (Select-String -Path $log -Pattern '^PASS:' | Measure-Object).Count
$fail = (Select-String -Path $log -Pattern '^FAIL:' | Measure-Object).Count
$done = Select-String -Path $log -Pattern 'ACCEPTANCE PASSED'

Write-Host ""
Select-String -Path $log -Pattern '^(PASS|FAIL):' | ForEach-Object {
    $line = $_.Line.Trim()
    if ($line -like 'FAIL:*') { Write-Host "  $line" -ForegroundColor Red }
    else                      { Write-Host "  $line" -ForegroundColor Green }
}

Write-Host ""
Write-Host "PASS: $pass   FAIL: $fail"

if ($fail -eq 0 -and $done) {
    Write-Host "ACCEPTANCE PASSED - the installed package works." -ForegroundColor Green
    Write-Host "Full log: $log"
    exit 0
}

Write-Host "ACCEPTANCE FAILED" -ForegroundColor Red
if ($fail -eq 0 -and -not $done) {
    Write-Host "No check failed, but the run did not reach the end - it aborted early." -ForegroundColor Yellow
    Write-Host "Last lines of the log:" -ForegroundColor Yellow
    Get-Content $log -Tail 15 | ForEach-Object { Write-Host "    $_" }
}
Write-Host "Full log: $log"
exit 1
