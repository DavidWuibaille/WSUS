# Remove Windows Updates by KB (PowerShell)

Uninstalls all installed Windows packages whose name matches a given **KB** via DISM PowerShell cmdlets.

## Usage
```powershell
# Uninstall all packages matching the KB
Remove-Package -KB "KB4589210"
```

## Full documentation
[Uninstalling Windows Updates (PowerShell)](https://blog.wuibaille.fr/2023/09/uninstalling-windows-updates-with-powershell/)
