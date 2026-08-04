# Legacy App Cleanup & Replace — Intune Deployment Template

A reusable, config-driven PowerShell solution for Intune Win32 app deployments
that need to **safely replace an existing application** — waiting for it to be
idle, closing it, uninstalling the old version, cleaning up leftovers, and
installing the new version — all logged and detectable by Intune.

Originally built for a real-world softphone client replacement, generalized
here so it works for any Windows desktop application.

## Why this exists
Most "just run msiexec" deployment scripts break when the old app is actively
in use by the end user, or leave orphaned registry keys/folders behind after
uninstall. This template handles both problems, plus multi-user/shared-device
scenarios where more than one Windows profile has the app installed.

## Structure
| File | Purpose |
|---|---|
| `Config.ps1` | Single file to edit — all app-specific values, with guidance on how to find each one |
| `Modules/ActiveUsageGuard.ps1` | Reusable module: detect if an app is idle/in-use, wait, then close it |
| `PreInstall.ps1` | Waits for old app to be idle, closes it, uninstalls it, cleans registry/folders |
| `Install.ps1` | Orchestrator: runs PreInstall → installs new MSI → verifies → logs |
| `Uninstall.ps1` | Standalone MSI/EXE uninstall cascade (also used internally by PreInstall) |
| `Detection.ps1` | Intune detection script — confirms correct app + version present |

## Quick start
1. Edit `Config.ps1` — see inline comments for how to find each value in your environment.
2. Drop your app's `.msi` (matching `$NewInstallerName`) into this folder.
3. See [DEPLOYMENT.md](./DEPLOYMENT.md) for full Intune packaging steps, context requirements, and testing guidance.

## License
MIT — see repo root LICENSE.
