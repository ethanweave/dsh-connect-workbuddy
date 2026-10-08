# install.ps1 - One-shot installer: download the official binary, verify SHA256,
# install the logon scheduled task. No admin rights required.

[CmdletBinding()]
param(
    [string]$Version = 'latest',
    [int]$Port = 8317,
    [switch]$Force,
    [switch]$NoTask
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')
$GwPort = $Port

$upstreamRepo = 'CangShui/workbuddy-gateway'
$assetName = 'workbuddy-gateway-windows-amd64.exe'

Write-Host "==> WorkBuddy Gateway installer" -ForegroundColor Cyan
Write-Host "    Install dir : $GwDir"
Write-Host "    Version     : $Version"
Write-Host "    Port        : $Port"

# --- 0. Already installed? --------------------------------------------------
if (-not $Force -and (Test-GatewayHealth)) {
    Write-Host "==> Gateway already responds on port $Port; nothing to install." -ForegroundColor Yellow
    Write-Host "    Use manage.ps1 update to upgrade the binary."
    return
}

# --- 1. Resolve the release version ----------------------------------------
# Direct download URLs only (no GitHub API): anonymous API calls are tightly
# rate-limited, while release asset downloads are not.
Write-Host "==> Downloading from upstream releases ($Version)..." -ForegroundColor Cyan
$base = "https://github.com/$upstreamRepo/releases"
if ($Version -eq 'latest') {
    $dlBase = "$base/latest/download"
    $tag = 'latest'
} else {
    $dlBase = "$base/download/$Version"
    $tag = $Version
}

# --- 2. Download binary + SHA256SUMS ----------------------------------------
$dlDir = Join-Path $env:TEMP "workbuddy-gateway-install-$tag"
New-Item -ItemType Directory -Path $dlDir -Force | Out-Null

$exeTmp = Join-Path $dlDir $assetName
$sumsTmp = Join-Path $dlDir 'SHA256SUMS'
Write-Host "==> Downloading $assetName..." -ForegroundColor Cyan
Invoke-WebRequest -Uri "$dlBase/$assetName" -OutFile $exeTmp -UseBasicParsing
Invoke-WebRequest -Uri "$dlBase/SHA256SUMS" -OutFile $sumsTmp -UseBasicParsing
Write-Host "    Downloaded ($([Math]::Round((Get-Item $exeTmp).Length / 1MB, 1)) MB)"

# --- 3. Verify checksum ------------------------------------------------------
Write-Host "==> Verifying SHA256..." -ForegroundColor Cyan
$expected = (Get-Content $sumsTmp | ForEach-Object {
    $parts = $_ -split '\s+', 2
    if ($parts.Count -eq 2 -and $parts[1].Trim() -eq $assetName) { $parts[0].ToLower() }
})
if (-not $expected) { throw "SHA256SUMS does not cover $assetName; aborting." }
$actual = (Get-FileHash -Path $exeTmp -Algorithm SHA256).Hash.ToLower()
if ($actual -ne $expected) { throw "Checksum mismatch! expected=$expected actual=$actual" }
Write-Host "    Checksum OK ($actual)" -ForegroundColor Green

# --- 4. Install files --------------------------------------------------------
New-Item -ItemType Directory -Path $GwDir -Force | Out-Null
if (Test-GatewayProcess) {
    Write-Host "==> Stopping running gateway before replacing binary..." -ForegroundColor Yellow
    Stop-Gateway
}
Copy-Item -Path $exeTmp -Destination $GwExe -Force

# Ship the suite scripts next to the gateway so the task is self-contained
# even if this repo checkout is deleted.
$dstScripts = Join-Path $GwDir 'scripts'
New-Item -ItemType Directory -Path $dstScripts -Force | Out-Null
Copy-Item -Path (Join-Path $PSScriptRoot 'common.ps1') -Destination $dstScripts -Force
Copy-Item -Path (Join-Path $PSScriptRoot 'gateway-task.ps1') -Destination $dstScripts -Force

# --- 5. Register the logon task ---------------------------------------------
if (-not $NoTask) {
    Write-Host "==> Registering logon scheduled task '$GwTaskName'..." -ForegroundColor Cyan
    Register-GatewayTask -TaskScript (Join-Path $dstScripts 'gateway-task.ps1')
}

# --- 6. First launch ---------------------------------------------------------
if (-not (Test-Path (Join-Path $GwDir 'workbuddy.json'))) {
    Write-Host ""
    Write-Host "==> No credentials found. Please log in now:" -ForegroundColor Yellow
    Write-Host "    & `"$GwExe`" login"
    Write-Host "    (or 'login -intl' for the international site)"
    Write-Host ""
    Write-Host "After login, run:  .\scripts\manage.ps1 start"
} else {
    Write-Host "==> Starting gateway..." -ForegroundColor Cyan
    if (Start-Gateway) {
        Write-Host "==> Gateway is healthy at $GwBaseUrl/v1/models" -ForegroundColor Green
    } else {
        Write-Host "==> Gateway did not answer yet; check $GwLogDir" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Done. Manage with:  .\scripts\manage.ps1 status|start|stop|restart|logs|update|uninstall"
