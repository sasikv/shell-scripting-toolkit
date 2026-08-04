## Intune Folder Copy Deployment

A lightweight Install/Uninstall script pair for deploying applications via Microsoft Intune 
when no MSI/EXE installer is available — instead, a pre-built application folder is copied 
directly into the target user's AppData directory.

### How it works
- `Install.ps1` copies `<AppFolderName>` from the script's own directory into 
  `%APPDATA%\<AppVendor>\<AppFolderName>`
- `Uninstall.ps1` removes that folder
- Both scripts log to `%APPDATA%\<AppVendor>\Install.log` / `Uninstall.log` and return 
  proper exit codes (0 = success, 1 = failure) for Intune detection rules

### Usage
1. Set `$AppVendor` and `$AppFolderName` at the top of each script
2. Place the application folder alongside the script (or package both into an Intunewin file)
3. Configure as a Win32 app in Intune, using `Install.ps1` / `Uninstall.ps1` as the install/uninstall commands
4. Use file existence of the target folder as your detection rule

### Notes
Originally built for deploying Avaya Agent as an example, but the vendor/app names are 
parameterized so it can be reused for any folder-based deployment.
