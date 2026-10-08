# manage.ps1 - Daily management entry: status / start / stop / restart / logs / update / uninstall

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('status', 'start', 'stop', 'restart', 'logs', 'update', 'uninstall')]
    [string]$Action,

    [int]$Lines = 50,
    [string]$Version = 'latest',
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')

switch ($Action) {

    'status' {
        $task = Get-GatewayTask
        $proc = Get-GatewayProcess
        $port = Get-NetTCPConnection -LocalPort $GwPort -State Listen -ErrorAction SilentlyContinue
        $http = Test-GatewayHealth

        $rows = @(
            [pscustomobject]@{ Check = 'ScheduledTask'; Result = $(if ($task) { "$($task.State)" } else { 'Not registered' }) },
            [pscustomobject]@{ Check = 'Process';       Result = $(if ($proc) { "PID $($proc.Id -join ',')" } else { 'Not running' }) },
            [pscustomobject]@{ Check = 'Port';          Result = $(if ($port) { "$GwPort listening" } else { "$GwPort closed" }) },
            [pscustomobject]@{ Check = 'HTTP';          Result = $(if ($http) { "OK ($GwBaseUrl/v1/models -> 200)" } else { 'Unreachable' }) }
        )
        $rows | Format-Table -AutoSize

        if ($http) {
            Write-Host 'Gateway is UP.' -ForegroundColor Green
        } elseif ($proc) {
            Write-Host 'Process exists but API is unreachable; check logs: manage.ps1 logs' -ForegroundColor Yellow
        } else {
            Write-Host 'Gateway is DOWN. Try: manage.ps1 start' -ForegroundColor Red
        }
    }

    'start' {
        Write-Host 'Starting gateway...'
        if (Start-Gateway) {
            Write-Host "Gateway is healthy at $GwBaseUrl/v1/models" -ForegroundColor Green
        } else {
            Write-Host 'Gateway did not become healthy in time; check: manage.ps1 logs' -ForegroundColor Red
            exit 1
        }
    }

    'stop' {
        Write-Host 'Stopping gateway...'
        Stop-Gateway
        Write-Host 'Gateway stopped.' -ForegroundColor Green
    }

    'restart' {
        & $MyInvocation.MyCommand.Path -Action stop
        & $MyInvocation.MyCommand.Path -Action start
    }

    'logs' {
        $today = Get-Date -Format 'yyyy-MM-dd'
        $candidates = @(
            (Join-Path $GwLogDir "gateway-$today.log"),
            (Join-Path $GwLogDir 'startup-task.log'),
            (Join-Path $GwLogDir 'gateway-stderr.log')
        )
        $picked = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
        if (-not $picked) {
            Write-Host "No logs yet under $GwLogDir" -ForegroundColor Yellow
            return
        }
        Write-Host "--- $picked (last $Lines lines) ---" -ForegroundColor Cyan
        Get-Content -LiteralPath $picked -Tail $Lines
    }

    'update' {
        Write-Host 'Updating binary via installer (task/config are preserved)...'
        $install = Join-Path $PSScriptRoot 'install.ps1'
        if ($Version -eq 'latest') {
            & $install
        } else {
            & $install -Version $Version
        }
        Write-Host 'Restarting gateway...'
        if (Start-Gateway) {
            Write-Host 'Update complete; gateway healthy.' -ForegroundColor Green
        } else {
            Write-Host 'Gateway not healthy after update; check logs.' -ForegroundColor Red
            exit 1
        }
    }

    'uninstall' {
        if (-not $Force) {
            $answer = Read-Host "Remove task, stop gateway and DELETE $GwDir? (y/N)"
            if ($answer -notin @('y', 'Y', 'yes')) {
                Write-Host 'Aborted.'
                return
            }
        }
        Write-Host 'Stopping gateway and removing task...'
        Stop-Gateway
        Unregister-GatewayTask
        if (Test-Path -LiteralPath $GwDir) {
            Remove-Item -LiteralPath $GwDir -Recurse -Force
        }
        Write-Host 'Uninstalled. Note: your upstream account credentials were deleted with the folder.' -ForegroundColor Yellow
    }
}
