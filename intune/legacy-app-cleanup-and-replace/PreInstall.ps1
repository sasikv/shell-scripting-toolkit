#Requires -Version 5.1
<#
.SYNOPSIS
    Generic pre-install: waits for the old app to be idle, closes it,
    uninstalls it, and cleans residual registry/folders.

.NOTES
    Runs as SYSTEM via Intune. Dot-sources Config.ps1 and Modules\ActiveUsageGuard.ps1.

    IMPORTANT: AppData\<App> is intentionally NOT cleaned here. This preserves
    the user's settings/preferences/cache across the reinstall — only remove
    this exclusion if you specifically need a clean-slate reinstall and have
    confirmed users are OK losing their local app data.
#>

. "$PSScriptRoot\Config.ps1"
. "$PSScriptRoot\Modules\ActiveUsageGuard.ps1"

New-Item -ItemType Directory -Force -Path $SharedLogDir | Out-Null
$LogFile = "$SharedLogDir\PreInstall.log"

function Write-Log {
    param([string]$Message, [ValidateSet("INFO","WARN","ERROR","SUCCESS")][string]$Level = "INFO")
    $entry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message"
    Add-Content -Path $LogFile -Value $entry -Encoding UTF8
    Write-Host $entry
}
$LogAction = { param($msg, $level) Write-Log $msg $level }

Write-Log "PreInstall started for $AppDisplayName. Running as: $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)" "INFO"

# Requires SYSTEM context: needs to close processes across ALL logged-in users
# on a shared device, not just the interactively active session.
Wait-ForAppIdle -ProcessNames $AppProcessNames -WatchedPorts $WatchedActivePorts `
    -MaxWaitMinutes $MaxWaitMinutes -CheckIntervalMinutes $CheckIntervalMinutes -LogAction $LogAction | Out-Null

Stop-AppProcesses -ProcessNames $AppProcessNames -FuzzyNameMatch $AppFuzzyMatch -LogAction $LogAction
Start-Sleep -Seconds 5

Write-Log "Invoking Uninstall.ps1 for existing $AppDisplayName installs..." "INFO"
& "$PSScriptRoot\Uninstall.ps1" -DisplayNamePatterns $AppRegistryPatterns -LogFile "$SharedLogDir\PreInstall_Uninstall.log"
$uninstallExit = $LASTEXITCODE

if ($uninstallExit -ne 0) {
    Write-Log "Uninstall step reported failure (exit $uninstallExit). Aborting PreInstall." "ERROR"
    exit 1
}

# ── Registry cleanup: HKLM + every user's HKCU hive (not just the active session) ──
# On shared/multi-user devices, other users' hives aren't loaded unless we mount
# their NTUSER.DAT manually — this loop handles both cases.
foreach ($regPath in @("HKLM:\SOFTWARE\LegacyApp", "HKLM:\SOFTWARE\WOW6432Node\LegacyApp")) {
    if (Test-Path $regPath) {
        try { Remove-Item $regPath -Recurse -Force -ErrorAction Stop; Write-Log "Removed $regPath" "SUCCESS" }
        catch { Write-Log "Failed to remove $regPath : $_" "WARN" }
    }
}

$userProfiles = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\*" -ErrorAction SilentlyContinue |
    Where-Object { $_.ProfileImagePath -match "C:\\Users\\" -and $_.ProfileImagePath -notmatch "Default|Public|systemprofile|LocalService|NetworkService" }

foreach ($up in $userProfiles) {
    $sidKey = $up.PSChildName
    $ntUserFile = "$($up.ProfileImagePath)\NTUSER.DAT"
    $tempMount = $false
    if (-not (Test-Path "Registry::HKEY_USERS\$sidKey") -and (Test-Path $ntUserFile)) {
        reg load "HKU\$sidKey" $ntUserFile 2>&1 | Out-Null
        $tempMount = $true
        Start-Sleep -Milliseconds 500
    }
    $hkuPath = "Registry::HKEY_USERS\$sidKey\SOFTWARE\LegacyApp"
    if (Test-Path $hkuPath) {
        try { Remove-Item $hkuPath -Recurse -Force -ErrorAction Stop; Write-Log "Removed HKU key for $($up.ProfileImagePath)" "SUCCESS" }
        catch { Write-Log "Failed to remove HKU key: $_" "WARN" }
    }
    if ($tempMount) {
        [GC]::Collect(); Start-Sleep -Milliseconds 500
        reg unload "HKU\$sidKey" 2>&1 | Out-Null
    }
}

# Program Files cleanup, with a robocopy mirror-empty trick as fallback for
# folders that Remove-Item can't touch because a lingering process still
# holds a file handle open.
foreach ($folder in $AppProgramFolders) {
    if (Test-Path $folder) {
        try { Remove-Item $folder -Recurse -Force -ErrorAction Stop; Write-Log "Removed $folder" "SUCCESS" }
        catch {
            Write-Log "Locked folder, trying robocopy mirror-empty trick: $folder" "WARN"
            $empty = "$env:TEMP\EmptyDir_$(Get-Random)"
            New-Item -ItemType Directory -Path $empty -Force | Out-Null
            robocopy $empty $folder /MIR /NFL /NDL /NJH /NJS /NC /NS /NP 2>&1 | Out-Null
            Remove-Item $folder -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item $empty -Force -ErrorAction SilentlyContinue
        }
    }
}

Write-Log "PreInstall completed successfully." "SUCCESS"
exit 0
