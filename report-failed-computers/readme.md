# WSUS – Failed Computers (Display.ps1)
Generate a CSV of client machines that had Windows Update installation errors over a recent time window, by querying **WSUS event history (errors only)**. Faster and more accurate than stitching multiple daily exports. If the `UpdateServices` module isn’t present, the script uses the WSUS Admin .NET DLL directly.

---

## Requirements

- Run on the **WSUS server**, in an **elevated** 64-bit Windows PowerShell (5.1).
- WSUS PowerShell module `UpdateServices` (installed with WSUS/RSAT) **or** the Admin DLL:
  `C:\Program Files\Update Services\Tools\Microsoft.UpdateServices.Administration.dll`
- Local access to WSUS (HTTP 8530 or HTTPS 8531).

---

## Install

1. Copy the script here: `DisplayToErrorComputer/Display.ps1`
2. Unblock if downloaded from the internet:
   ```powershell
   Unblock-File .\Display.ps1
   ```
   
## How to run
Standard run (last 7 days, top 100):
   ```powershell
   .\Display.ps1 -Days 7 -Top 100 -Verbose
   ```