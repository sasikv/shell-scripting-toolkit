<#
    Config.ps1 — Edit this file only. Everything else dot-sources these values.
    See the "How to find these values" comments below each setting.
#>

# ─────────────────────────────────────────────────────────────
# APP DISPLAY NAME — cosmetic only, shown in logs/prompts
# ─────────────────────────────────────────────────────────────
$AppDisplayName = "Legacy Communication Client"


# ─────────────────────────────────────────────────────────────
# PROCESS NAMES — used to detect/close the running app
#
# HOW TO FIND:
#   1. Open the app normally on a test machine.
#   2. Open Task Manager → Details tab → find the app's process(es).
#      The "Name" column (without .exe) is what goes here.
#   3. Alternatively, run this in PowerShell WHILE the app is open:
#         Get-Process | Where-Object { $_.MainWindowTitle -ne "" } | 
#             Select-Object Name, MainWindowTitle
#      This lists only processes with a visible window, making it 
#      easy to spot the right one.
#   4. Some apps spawn multiple processes (a main UI + a background 
#      agent/helper). List ALL of them here — check Task Manager 
#      again a minute after opening the app, since some helpers 
#      start late.
#
# NOTE: Names WITH spaces (e.g. "My App Name") work fine here — 
#       this template does not use Get-Process -Name (which breaks 
#       on spaces), it filters the full process list instead.
# ─────────────────────────────────────────────────────────────
$AppProcessNames = @("LegacyApp", "LegacyAppAgent")


# ─────────────────────────────────────────────────────────────
# FUZZY MATCH — safety-net substring match (case-insensitive)
# Catches any process you missed above, e.g. if a future app 
# update adds a new helper process you didn't know about.
#
# HOW TO FIND: usually just the vendor or product name in lowercase, 
# e.g. "zoom", "webex", "avaya". Leave as "" to disable this safety net 
# if you're confident your process list above is complete — an overly 
# broad fuzzy match risks closing an unrelated process that happens 
# to share the substring.
# ─────────────────────────────────────────────────────────────
$AppFuzzyMatch = "legacyapp"


# ─────────────────────────────────────────────────────────────
# REGISTRY DISPLAY NAME PATTERNS — used to find the app in 
# Windows' uninstall registry (this is what "Apps & Features" reads from)
#
# HOW TO FIND:
#   1. Run this in PowerShell on a machine with the app installed:
#         Get-ItemProperty `
#           "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
#           "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" |
#           Where-Object DisplayName -like "*PART_OF_APP_NAME*" |
#           Select-Object DisplayName, DisplayVersion, PSChildName
#   2. Use a short/partial guess first (e.g. "*Legacy*") to find the 
#      exact DisplayName, then narrow your pattern.
#   3. If the app has multiple components (main app + separate agent), 
#      list each DisplayName pattern separately — they usually have 
#      separate registry entries.
#
# This is DIFFERENT from the process name above — DisplayName is a 
# human-readable string set by the installer, not the .exe name.
# ─────────────────────────────────────────────────────────────
$AppRegistryPatterns = @("Legacy Communication Client", "Legacy Client Agent")


# ─────────────────────────────────────────────────────────────
# PROGRAM FILES FOLDERS — cleaned up after uninstall in case the 
# installer leaves orphaned files behind
#
# HOW TO FIND: check both of these after uninstalling the app manually:
#     C:\Program Files\<VendorOrAppName>
#     C:\Program Files (x86)\<VendorOrAppName>
#   Whichever still has files left behind, add its exact path here.
#   If the uninstaller cleans up completely on its own, you can 
#   leave this as an empty array: @()
# ─────────────────────────────────────────────────────────────
$AppProgramFolders = @("C:\Program Files\LegacyApp", "C:\Program Files (x86)\LegacyApp")


# ─────────────────────────────────────────────────────────────
# WATCHED PORTS — used to detect if the app is mid-active-use 
# (e.g. an active call/session), not just open
#
# HOW TO FIND: this only matters for real-time communication apps 
# (softphones, video clients). If your app isn't one of those, 
# leave this as an empty array: @() — the script will then treat 
# "app is running" as enough reason to wait, without trying to 
# distinguish "open" from "actively in a call."
#
# To find the right ports for a comms app:
#   1. Start a test call/session using the app.
#   2. Run: netstat -ano | findstr ESTABLISHED
#   3. Cross-reference the PID column against the app's PID in 
#      Task Manager to find which connections belong to it.
#   4. Common ones: SIP signaling = 5060 (unencrypted) / 5061 (TLS).
#      RTP media is usually a random high port per call, which is 
#      why this template also treats any ESTABLISHED connection 
#      in typical RTP ranges as "active" — check your vendor's 
#      documentation for their specific port range if unsure.
# ─────────────────────────────────────────────────────────────
$WatchedActivePorts = @(5060, 5061)


$MaxWaitMinutes       = 180   # max time to wait for the app to go idle before forcing closure
$CheckIntervalMinutes = 10    # how often to re-check during the wait


# ─────────────────────────────────────────────────────────────
# NEW INSTALLER FILENAME — must exactly match the MSI file you 
# place alongside these scripts (case-sensitive on some systems, 
# and Intune packaging is picky about exact filename matches)
#
# HOW TO FIND: this is simply the filename of the .msi you were 
# given/downloaded — e.g. right-click the file → Properties, or 
# just copy the filename as it appears in File Explorer, spaces 
# and all. Do not rename the MSI unless you're sure it doesn't 
# break a vendor-signed installer check.
# ─────────────────────────────────────────────────────────────
$NewInstallerName = "LegacyAppSetup.msi"


# ─────────────────────────────────────────────────────────────
# VERSION STRING TO VERIFY POST-INSTALL — used by Install.ps1 and 
# Detection.ps1 to confirm the correct version landed
#
# HOW TO FIND: install the new MSI manually once on a test machine, then run:
#     Get-ItemProperty `
#       "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
#       "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" |
#       Where-Object DisplayName -like "*YourAppName*" |
#       Select-Object DisplayName, DisplayVersion
#   Use the DisplayVersion value exactly as shown (or a truncated 
#   prefix of it, e.g. "3.40.2" to match "3.40.2.10.51" loosely).
# ─────────────────────────────────────────────────────────────
$NewVersionRegistry = "2.0.0"


$SharedLogDir = "C:\ProgramData\IntuneDeploy\LegacyApp"   # log location — readable by SYSTEM/admins, survives reboots
