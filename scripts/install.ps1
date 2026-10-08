# install.ps1 - One-shot installer: download the official binary, verify SHA256,
# install the logon scheduled task. No admin rights required.

[CmdletBinding()]
param(
    [string]$Version = 'latest',
    [int]$Port = 8317,
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
if (Test-GatewayHealth) {
    Write-Host "==> Gateway already responds on port $Port; nothing to install." -ForegroundColor Yellow
    Write-Host "    Use manage.ps1 update to upgrade the binary."
    return
}

# --- 1. Resolve the release version ----------------------------------------
Write-Host "==> Resolving release..." -ForegroundColor Cyan
$headers = @{ 'User-Agent' = 'workbuddy-gateway-windows-installer' }
$relUrl = "https://api.github.com/repos/$upstreamRepo/releases"
if ($Version -eq 'latest') { $relUrl += '/latest' } else { $relUrl += "/tags/$Version" }
$release = Invoke-RestMethod -Uri $relUrl -Headers $headers
$tag = $release.tag_name
Write-Host "    Resolved: $tag"

# --- 2. Download binary + SHA256SUMS ----------------------------------------
$dlDir = Join-Path $env:TEMP "workbuddy-gateway-install-$tag"
New-Item -ItemType Directory -Path $dlDir -Force | Out-Null
$asset = $release.assets | Where-Object { $_.name -eq $assetName } | Select-Object -First 1
if (-not $asset) { throw "Asset $assetName not found in release $tag." }

$exeTmp = Join-Path $dlDir $assetName
$sumsTmp = Join-Path $dlDir 'SHA256SUMS'
Write-Host "==> Downloading $($asset.name) ($([Math]::Round($asset.size / 1MB, 1)) MB)..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $exeTmp -UseBasicParsing
Invoke-WebRequest -Uri "$($release.browser_download_url -replace '/[^/]+$', '')/SHA256SUMS" `
    -OutFile $sumsTmp -UseBasicParsing

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
