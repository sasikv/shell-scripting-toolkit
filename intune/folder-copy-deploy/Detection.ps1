<#
.SYNOPSIS
    Intune detection script for the Avaya Agent folder-copy deployment.
    Exits 0 with output if detected (installed), exits 1 with no output if not.
#>

$AppVendor     = "Avaya"
$AppFolderName = "Avaya Agent"
$TargetFolder  = "$env:APPDATA\$AppVendor\$AppFolderName"

# Adjust this to a specific file that proves a real install (not just an empty folder)
$MarkerFile = "$TargetFolder\Avaya Agent.exe"

if (Test-Path $MarkerFile) {
    Write-Output "Detected: $MarkerFile"
    exit 0
}
else {
    exit 1
}
