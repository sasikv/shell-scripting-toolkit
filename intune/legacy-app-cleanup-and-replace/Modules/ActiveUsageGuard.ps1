<#
.SYNOPSIS
    Reusable module: detects whether a target application is actively in use
    (e.g., mid-call for a softphone, mid-transfer for a sync client) and
    waits/prompts before allowing a caller script to close it.

.DESCRIPTION
    Dot-source this file from a pre-install script before uninstalling or
    upgrading an application that may be mid-task for the user.

    Exposes:
      Test-AppActiveUsage      - returns running process objects matching the app
      Test-AppActiveConnection - returns $true if a process holds an ESTABLISHED
                                 connection on any of the given ports
      Wait-ForAppIdle          - polls until app is idle or max wait time elapses
      Stop-AppProcesses        - gracefully then forcefully closes target processes

    This module has no app-specific logic — the same file works for any app,
    the config values come from the caller.
#>

function Test-AppActiveUsage {
    param(
        [Parameter(Mandatory)][string[]]$ProcessNames,
        [string]$FuzzyNameMatch  # optional: substring safety net, e.g. "zoom"
    )
    # Filtering the full process list (rather than Get-Process -Name) so that
    # process names WITH SPACES (e.g. "My App Name") work correctly.
    $allProcesses = Get-Process -ErrorAction SilentlyContinue
    $running = $allProcesses | Where-Object { $_.Name -in $ProcessNames }
    if ($FuzzyNameMatch) {
        $running += $allProcesses | Where-Object {
            $_.Name -match $FuzzyNameMatch -and $running.Id -notcontains $_.Id
        }
    }
    return @($running)
}

function Test-AppActiveConnection {
    param(
        [Parameter(Mandatory)][System.Diagnostics.Process[]]$Processes,
        [Parameter(Mandatory)][int[]]$WatchedPorts
    )
    # If WatchedPorts is empty, this always returns $false (no connection-based
    # check) — Wait-ForAppIdle treats "process running" alone as busy in that case.
    foreach ($proc in $Processes) {
        try {
            $conns = netstat -ano 2>$null | Select-String "ESTABLISHED" | Select-String "\s+$($proc.Id)$"
            foreach ($line in $conns) {
                foreach ($port in $WatchedPorts) {
                    if ($line -match ":$port\s") { return $true }
                }
            }
        }
        catch { }
    }
    return $false
}

function Wait-ForAppIdle {
    param(
        [Parameter(Mandatory)][string[]]$ProcessNames,
        [int[]]$WatchedPorts = @(),
        [int]$MaxWaitMinutes = 180,
        [int]$CheckIntervalMinutes = 10,
        [scriptblock]$LogAction = { param($msg, $level) Write-Host "[$level] $msg" }
    )
    $elapsed = 0
    while ($elapsed -lt $MaxWaitMinutes) {
        $running = Test-AppActiveUsage -ProcessNames $ProcessNames
        if ($running.Count -eq 0) {
            & $LogAction "App is closed. Proceeding." "SUCCESS"
            return $true
        }
        if ($WatchedPorts.Count -gt 0) {
            $onCall = Test-AppActiveConnection -Processes $running -WatchedPorts $WatchedPorts
            if (-not $onCall) {
                & $LogAction "App running but idle (no active connection). Proceeding." "INFO"
                return $true
            }
        } else {
            # No ports configured — app being open at all counts as "in use."
            & $LogAction "App is running (no port check configured). Waiting." "INFO"
        }
        $remaining = $MaxWaitMinutes - $elapsed
        & $LogAction "App in use. Re-checking in $CheckIntervalMinutes min ($remaining min remaining)." "INFO"
        Start-Sleep -Seconds ($CheckIntervalMinutes * 60)
        $elapsed += $CheckIntervalMinutes
    }
    & $LogAction "Max wait ($MaxWaitMinutes min) reached. Proceeding regardless of usage state." "WARN"
    return $false
}

function Stop-AppProcesses {
    param(
        [Parameter(Mandatory)][string[]]$ProcessNames,
        [string]$FuzzyNameMatch,
        [scriptblock]$LogAction = { param($msg, $level) Write-Host "[$level] $msg" }
    )
    $allProcs = Get-Process -ErrorAction SilentlyContinue
    $targets = $allProcs | Where-Object { $_.Name -in $ProcessNames }
    if ($FuzzyNameMatch) {
        $targets += $allProcs | Where-Object {
            $_.Name -match $FuzzyNameMatch -and $targets.Id -notcontains $_.Id
        }
    }
    foreach ($proc in $targets) {
        & $LogAction "Closing: $($proc.Name) (PID: $($proc.Id))" "INFO"
        try {
            $proc.CloseMainWindow() | Out-Null
            $proc | Wait-Process -Timeout 10 -ErrorAction SilentlyContinue
        } catch { }
        if (-not $proc.HasExited) {
            & $LogAction "Force killing: $($proc.Name)" "WARN"
            try { $proc | Stop-Process -Force -ErrorAction SilentlyContinue } catch { }
        }
    }
}
