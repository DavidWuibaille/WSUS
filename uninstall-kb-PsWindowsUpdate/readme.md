# Uninstall a Windows Update by KB (PSWindowsUpdate)

Minimal helper and examples to remove an installed Windows update by its **KB** number using the **PSWindowsUpdate** module.

## Requirements
- Run PowerShell **as Administrator**.
- Module: `PSWindowsUpdate` (install if needed: `Install-Module PSWindowsUpdate -Scope CurrentUser`).
- A reboot may be required after removal.

## Quick commands (no wrapper)
```powershell
# List installed updates matching the KB
Get-WindowsUpdate -IsInstalled -KBArticleID KB5028952

# Uninstall (no auto-restart)
Remove-WindowsUpdate -KBArticleID KB5028952 -NoRestart -Confirm:$false
```

## Script usage
If you saved the wrapper as `Remove-KB.ps1`:
```powershell
# Example
.\Remove-KB.ps1 -KB KB5028952 -NoRestart
```

## Notes
- Some updates (especially **Servicing Stack Updates**) cannot be uninstalled.
- If removal via PSWindowsUpdate fails for a cumulative update, find the exact package name and try DISM:
  ```powershell
  DISM /Online /Get-Packages
  DISM /Online /Remove-Package /PackageName:<ExactName> /Quiet /NoRestart
  ```
- Logs: `C:\Windows\Logs\WindowsUpdate\windowsupdate.log` and `C:\Windows\Logs\CBS\CBS.log`.

