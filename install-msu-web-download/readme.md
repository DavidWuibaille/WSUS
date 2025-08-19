# MSU Direct Download & Silent Install (PowerShell)

Download a specific **MSU** from Microsoft Update Catalog, run **pre-checks**, install with `wusa.exe /quiet /norestart`, and return the installer’s exit code. Logs to `C:\Windows\Temp\MSU_Install.log`.

## What it checks
- **Pending reboot** → exits **101**.
- **Free space on C:** ≥ **5 GB** (default) → exits **103**.
- **Download** success from the Catalog URL → exits **104** on failure.
- Otherwise runs `wusa` and returns its native **exit code** (`0` OK, `3010` reboot required).

## Quick start
1. Edit the variables at the top of the script:
   - `$MSUUrl` (direct Catalog URL)
   - `$MSUFile` (e.g. `windows10.0-kb5060531-x64.msu`)
   - Optional: `$minFreeGB`
2. Run as Administrator:
   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install-MSU.ps1
   ```

## Exit codes
- **0** = Installed successfully  
- **3010** = Installed, reboot required (from `wusa`)  
- **101** = Pending reboot detected  
- **103** = Not enough free space on C:  
- **104** = Download failed  
- **others** = Native `wusa.exe` codes

## Requirements
- Windows 10/11 or Server, **elevated** PowerShell.
- Outbound access to the Microsoft Update Catalog URL.
- `wusa.exe` available (built-in).

## Notes
- The script deletes any existing MSU at the target path before downloading.
- If proxy/TLS blocks `WebClient`, switch to `Invoke-WebRequest` and enforce TLS 1.2:
  ```powershell
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  Invoke-WebRequest -Uri $MSUUrl -OutFile $MSUPath -UseBasicParsing
  ```

## Full article
https://blog.wuibaille.fr/2025/08/msu-direct-downlaod-and-silent-install/
