
<#
.SYNOPSIS
    Copies an application folder to a user's AppData directory. Designed for Intune Win32 app deployment.
.DESCRIPTION
    Copies "$PSScriptRoot\<AppFolderName>" to the target user's AppData\Roaming directory.
    Logs actions and exits with a non-zero code on failure so Intune can detect install failures.
#>

$AppVendor    = "Avaya"
$AppFolderName = "Avaya Agent"

$LogDir     = "$env:APPDATA\$AppVendor"
$InsLogFile = "$LogDir\Install.log"
$TargetFolder = "$LogDir\$AppFolderName"
$SourceFolder = "$PSScriptRoot\$AppFolderName"

if (!(Test-Path $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
}

if (Test-Path $InsLogFile) {
    Remove-Item $InsLogFile -Force -ErrorAction SilentlyContinue -Confirm:$false
}

function Write-Log {
    param ([Parameter(Mandatory = $true)][string]$Message)
    $TimeGenerated = Get-Date -UFormat "%D %T"
    Add-Content -Value "$TimeGenerated : $Message" -Path $InsLogFile -Encoding Ascii
}

Write-Log "Starting install: copying '$AppFolderName' folder"

if (!(Test-Path $TargetFolder)) {
    Write-Log "Target folder $TargetFolder does not exist, creating it"
    New-Item -Path $TargetFolder -ItemType Directory -Force | Out-Null
}

try {
    Copy-Item -Path "$SourceFolder\*" -Destination $TargetFolder -Recurse -Force -ErrorAction Stop
    Write-Log "SUCCESS: Contents copied from $SourceFolder to $TargetFolder"
    exit 0
}
catch {
    Write-Log "FAILURE: Could not copy $SourceFolder to $TargetFolder. Error: $($_.Exception.Message)"
    exit 1
}
