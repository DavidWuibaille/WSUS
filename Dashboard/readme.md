# WSUS HTML Report (PowerShell)

Generates a **single-page HTML dashboard** for WSUS: target-group inventory, KB deployment status (timeline + donuts), per-KB computer states, and a table of computers with failed updates.

## Features
- Computers by **Target Group** (table + pie).
- KB status per group: **Installed vs Missing** and **approval age timeline**.
- Per-KB list of affected computers (hidden sections you can expand).
- **Failed** updates: computers in error.

## Requirements
- Run on the **WSUS server** as Administrator.
- Module: `PSWriteHTML`  
  ```powershell
  Install-Module PSWriteHTML -Scope CurrentUser
  ```
- WSUS API available (either the `UpdateServices` module or
  `Microsoft.UpdateServices.Administration.dll` at  
  `"%ProgramFiles%\Update Services\Tools\Microsoft.UpdateServices.Administration.dll"`).
- The script uses `-Online` (CDN assets). Remove that flag if your server has no internet.

## Quick start
```powershell
# 1) Save the script as: C:\Scripts\Wsus-Report.ps1
# 2) Run it (elevated)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Scripts\Wsus-Report.ps1
# Output:
#   C:\exploit\report\default.htm
```

## Customize
- Output path: `$outFile` (default `C:\exploit\report\default.htm`).
- Exclusions for titles (ARM64, SSU, Flash, etc.) in the KB section.
- Table/chart IDs if you embed multiple reports.

## Full article
https://blog.wuibaille.fr/2024/10/creating-a-wsus-dashboard/
