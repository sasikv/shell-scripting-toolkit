<#
.SYNOPSIS
    Removes an application folder previously deployed via Install.ps1. Designed for Intune Win32 app deployment.
#>

$AppVendor    = "Avaya"
$AppFolderName = "Avaya Agent"

$LogDir       = "$env:APPDATA\$AppVendor"
$UninsLogFile = "$LogDir\Uninstall.log"
$TargetFolder = "$LogDir\$AppFolderName"

if (Test-Path $UninsLogFile) {
    Remove-Item $UninsLogFile -Force -ErrorAction SilentlyContinue -Confirm:$false
}

function Write-Log {
    param ([Parameter(Mandatory = $true)][string]$Message)
    $TimeGenerated = Get-Date -UFormat "%D %T"
    Add-Content -Value "$TimeGenerated : $Message" -Path $UninsLogFile -Encoding Ascii
}

Write-Log "Starting uninstall: removing '$AppFolderName' folder"

if (!(Test-Path $TargetFolder)) {
    Write-Log "Target folder $TargetFolder does not exist, nothing to do"
    exit 0
}

try {
    Remove-Item -Path $TargetFolder -Recurse -Force -ErrorAction Stop
    Write-Log "SUCCESS: $TargetFolder deleted"
    exit 0
}
catch {
    Write-Log "FAILURE: Could not delete $TargetFolder. Error: $($_.Exception.Message)"
    exit 1
}
