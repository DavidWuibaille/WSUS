# WSUS Cleanup (PowerShell)

Powershell scripts to run a safe, repeatable **WSUS** cleanup:
- Decline superseded/expired updates
- Remove obsolete updates/computers
- Compress updates
- Delete unneeded content files

Works with the supported WSUS cmdlets (`UpdateServices` module). A legacy .NET fallback is included.

---

## Requirements
- Run on the WSUS server in an **elevated** PowerShell session.
- WSUS PowerShell module: `UpdateServices` (installed with WSUS/RSAT).
- Port **8530** (HTTP) or **8531** (HTTPS).
- Expect long runtimes on large servers; schedule outside business hours.

## Quick start

```powershell
# Standard full cleanup (HTTP 8530)
.\Wsus-Cleanup.ps1 -Verbose

# HTTPS on 8531
.\Wsus-Cleanup.ps1 -UseSsl -Port 8531 -Verbose
