# Remove Windows Updates by KB (PowerShell)

Uninstalls all installed Windows packages whose name matches a given **KB** via DISM PowerShell cmdlets.

## Usage
```powershell
# List installed packages and filter by KB
Get-WindowsPackage -Online | Where-Object { $_.PackageName -match "KB5032189" } | Select-Object PackageName, State, InstallTime
```

```powershell
# Uninstall all packages matching the KB
Remove-Package -KB "KB4589210"
```

## Notes & limitations
MSU files: Remove-WindowsPackage removes packages in the image (.cab/package identities), not .msu directly
SSUs can’t be uninstalled: Servicing Stack Updates modify the update stack and are not removable.
After ResetBase: If you ran DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase, existing update packages can no longer be uninstalled.