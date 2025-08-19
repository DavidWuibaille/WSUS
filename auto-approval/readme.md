# WSUS – Automate Patch Assignment to Groups

PowerShell script to automatically **promote WSUS approvals** across groups after a delay, accept EULAs, and decline superseded updates when a newer update is approved in production.

## What it does
- Sync approvals after X days:
  - `Pilot  → Global1`
  - `Global1 → Global2`
- Accept license agreements when required.
- Decline superseded updates if a superseding update is approved for **Global2**.
- Write rotating logs to `C:\Logs` (keeps the latest 60 files).

## Requirements
- Run on the WSUS server with **Administrator** privileges.
- WSUS installed (PowerShell `UpdateServices` module or the WSUS Admin DLL available).
- Existing WSUS groups: `Pilot`, `Global1`, `Global2` (adjust names if different).

## Configuration
Edit the top of the script:
- `\$SyncApprovals` – define source/target groups and `MinDays`.
- `\$logFolder`, `\$maxLogs` – logging folder and retention.
- Superseded-decline rule currently targets `Global2`.

## Quick start
```powershell
# Run the script (no parameters)
.\Wsus-ManageApprovals.ps1
```

## Full documentation
https://blog.wuibaille.fr/2024/10/automate-assign-patch-to-group/