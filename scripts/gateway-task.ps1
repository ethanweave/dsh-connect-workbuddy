# gateway-task.ps1 - Executed by the "WorkBuddy Gateway" scheduled task at user logon.
# Probes the local API first so duplicate triggers never spawn a second instance.

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')

try {
    if (Test-GatewayHealth) {
        Write-GwLog 'Gateway API already responds; skipped duplicate launch.'
        exit 0
    }
} catch { }

if (-not (Test-Path -LiteralPath $GwExe)) {
    Write-GwLog 'Gateway executable is missing.'
    exit 2
}

Write-GwLog 'Starting gateway in background.'
$stdout = Join-Path $GwLogDir 'gateway-stdout.log'
$stderr = Join-Path $GwLogDir 'gateway-stderr.log'
$proc = Start-Process -FilePath $GwExe -ArgumentList 'serve' -WorkingDirectory $GwDir `
    -WindowStyle Hidden -PassThru `
    -RedirectStandardOutput $stdout -RedirectStandardError $stderr

# Confirm startup so the task log reflects reality, not just the spawn.
$ready = $false
for ($i = 0; $i -lt 20; $i++) {
    if ($proc.HasExited) { break }
    if (Test-GatewayHealth -TimeoutSec 2) { $ready = $true; break }
    Start-Sleep -Milliseconds 500
}
if ($ready) {
    Write-GwLog 'Gateway is healthy.'
} elseif ($proc.HasExited) {
    Write-GwLog "Gateway process exited immediately with code $($proc.ExitCode)."
} else {
    Write-GwLog 'Gateway process is up but the API has not answered yet; check gateway logs.'
}
