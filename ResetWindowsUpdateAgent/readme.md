# Reset Windows Update Components (PowerShell)

Two maintained scripts to fix stuck Windows Update on Windows 10/11 and Server:

- **cleanlight.ps1** — quick cache cleanup (fast, minimal).
- **cleanFull.ps1** — full component reset (deeper, reversible).

## What each script does
- `cleanlight.ps1`
  - Stops `wuauserv`
  - Deletes `%WINDIR%\SoftwareDistribution\Download` and `...\Datastore`
  - Restarts `wuauserv`
  - Log: `C:\Windows\Temp\Wuauserv_Cleanup.log`

- `cleanFull.ps1`
  - Stops `wuauserv`, `bits`, `cryptSvc`, `msiserver`
  - Renames `%WINDIR%\SoftwareDistribution` → `SoftwareDistribution.old`
  - Renames `%WINDIR%\System32\catroot2` → `catroot2.old`
  - Restarts services
  - Log: `C:\Windows\Temp\WUA_Reset.log`

> Note: Both approaches reset the **local** Windows Update history view. The first scan afterward can be longer.

## Requirements
- Run **as Administrator** on the affected device.
- Use **64-bit** PowerShell path.
- Close the Windows Update UI before running.

## Usage
```powershell
# Light cleanup
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Scripts\cleanlight.ps1

# Full reset
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Scripts\cleanFull.ps1
```

## After running
- Trigger a scan: `USOClient StartScan` (Win10/11) or wait for the next schedule.
- Optionally delete `*.old` folders after a few days if disk space matters.
- Check logs (paths above) if issues persist; see also `C:\Windows\WindowsUpdate.log` and `C:\Windows\Logs\CBS\CBS.log`.


