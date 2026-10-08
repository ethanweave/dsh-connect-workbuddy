# common.ps1 - Shared helpers for the WorkBuddy Gateway Windows suite.
# Dot-source this file, then override the $Gw* defaults from the caller if needed.

$GwDir      = Join-Path $env:USERPROFILE 'workbuddy-gateway'
$GwExe      = Join-Path $GwDir 'workbuddy-gateway.exe'
$GwLogDir   = Join-Path $GwDir 'logs'
$GwTaskName = 'WorkBuddy Gateway'
$GwPort     = 8317
$GwBaseUrl  = "http://127.0.0.1:$GwPort"

function Write-GwLog {
    param([string]$Message)
    if (-not (Test-Path -LiteralPath $GwLogDir)) {
        New-Item -ItemType Directory -Path $GwLogDir -Force | Out-Null
    }
    $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Add-Content -LiteralPath (Join-Path $GwLogDir 'startup-task.log') `
        -Value "$stamp $Message" -Encoding UTF8
}

function Test-GatewayHealth {
    param([int]$TimeoutSec = 3)
    try {
        $resp = Invoke-WebRequest -Uri "http://127.0.0.1:$GwPort/v1/models" `
            -TimeoutSec $TimeoutSec -UseBasicParsing
        return ([int]$resp.StatusCode -eq 200)
    } catch {
        return $false
    }
}

function Get-GatewayProcess {
    Get-Process -Name 'workbuddy-gateway' -ErrorAction SilentlyContinue
}

function Get-GatewayTask {
    Get-ScheduledTask -TaskName $GwTaskName -ErrorAction SilentlyContinue
}

function Register-GatewayTask {
    param(
        [Parameter(Mandatory = $true)][string]$TaskScript,
        [string]$Description = 'Start WorkBuddy Gateway (OpenAI-compatible local proxy) at user logon.'
    )
    if (-not (Test-Path -LiteralPath $TaskScript)) {
        throw "Task script not found: $TaskScript"
    }
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' `
        -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$TaskScript`""
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
        -StartWhenAvailable -MultipleInstances IgnoreNew `
        -ExecutionTimeLimit ([TimeSpan]::Zero) `
        -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
    Register-ScheduledTask -TaskName $GwTaskName -Action $action -Trigger $trigger `
        -Settings $settings -Description $Description -Force | Out-Null
}

function Unregister-GatewayTask {
    Unregister-ScheduledTask -TaskName $GwTaskName -Confirm:$false -ErrorAction SilentlyContinue
}

function Stop-Gateway {
    Stop-ScheduledTask -TaskName $GwTaskName -ErrorAction SilentlyContinue
    Get-GatewayProcess | Stop-Process -Force -ErrorAction SilentlyContinue
    # Give the listener a moment to release the port.
    for ($i = 0; $i -lt 10; $i++) {
        if (-not (Get-GatewayProcess)) { break }
        Start-Sleep -Milliseconds 300
    }
}

function Start-Gateway {
    # Preferred path: the scheduled task (same code path as logon autostart).
    $started = $false
    $task = Get-GatewayTask
    if ($task -and $task.State -ne 'Disabled') {
        try {
            Start-ScheduledTask -TaskName $GwTaskName -ErrorAction Stop
            $started = $true
        } catch { }
    }
    if (-not $started) {
        # Fallbacks when no task is registered: the installed task script, or the exe directly.
        $taskScript = Join-Path $GwDir 'scripts\gateway-task.ps1'
        if (Test-Path -LiteralPath $taskScript) {
            Start-Process -FilePath 'powershell.exe' `
                -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$taskScript`"" `
                -WindowStyle Hidden
        } else {
            Start-Process -FilePath $GwExe -ArgumentList 'serve' `
                -WorkingDirectory $GwDir -WindowStyle Hidden
        }
    }
    for ($i = 0; $i -lt 20; $i++) {
        if (Test-GatewayHealth -TimeoutSec 2) { return $true }
        Start-Sleep -Milliseconds 500
    }
    return $false
}
