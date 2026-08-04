# Deployment Guide

## 1. Customize
Edit `Config.ps1` only — set process names, registry patterns, folder paths, and the installer filename for your target app.

## 2. Package as .intunewin
Place all files + your app's MSI in one folder, then use the 
[Microsoft Win32 Content Prep Tool](https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool):

    IntuneWinAppUtil.exe -c <SourceFolder> -s Install.ps1 -o <OutputFolder>

## 3. Intune App Configuration

| Setting | Value |
|---|---|
| Install command | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File Install.ps1` |
| Uninstall command | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File Uninstall.ps1 -DisplayNamePatterns "App Name"` |
| Install behavior | **System** — required for HKLM registry access, killing other users' processes, and writing to Program Files |
| Device restart behavior | No specific action (script handles reboot suppression itself) |

### Why System context, not User
This deployment reads/writes HKLM, iterates *all* user profile hives (not just the interactively logged-in one), and needs rights to force-close processes owned by other sessions. User context would fail on all three. If your use case only ever touches the current user's HKCU and AppData, a User-context deployment is possible — but this template is built for the multi-user/shared-device System-context case.

## 4. Detection Rule
Use **Detection.ps1** as a custom detection script (not the built-in file/registry rule), since it needs to match app name *and* version together — the built-in rule only checks one condition per rule cleanly.

## 5. Logs
All scripts log to `C:\ProgramData\IntuneDeploy\<AppName>\`. This location is readable by SYSTEM and admins, and survives across reboots — useful for troubleshooting failed deployments after the fact via remote PowerShell or a log-collection profile.

## 6. Testing before rollout
1. Run `Install.ps1` locally as SYSTEM (`psexec -s -i powershell.exe`) on a test VM with the old app installed and running.
2. Confirm logs show the expected wait/close/uninstall/install/verify sequence.
3. Run `Detection.ps1` standalone and confirm exit code + stdout.
4. Deploy to a small Intune pilot group before broad rollout.
