# WSUS – Display Top Error Computers (PowerShell)

Find the **top N computers** with the most Windows Update failures in the last **N days** from WSUS, list their failed updates, and export results to CSV.

## What the script does
- Reads WSUS **event history** over a time window.
- Aggregates errors **per computer** and shows the **Top N**.
- Prints failed **KB titles per machine**.
- Exports a CSV: `WSUS_FailedComputers_YYYYMMDD.csv`.

## Requirements
- Run **on the WSUS server**, in an **elevated** 64-bit PowerShell.
- WSUS API available:
  - `UpdateServices` module **or**
  - `"%ProgramFiles%\Update Services\Tools\Microsoft.UpdateServices.Administration.dll"`.

## Usage
Save as `Top-ErrorComputers.ps1`, then run:
```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Top-ErrorComputers.ps1
```

## Configuration
Edit the variables at the top of the script:
- `$Days` – time window (default: `7`)
- `$Top`  – number of computers to display (default: `10`)
- `$OutCsv` – export path

## Output
- Console table: `ComputerName`, `IPAddress`, `Errors`, `LastError`
- CSV file at `$OutCsv`
- For each “top” computer, a list of **failed update titles** is printed below the table.

## Optional: schedule (Task Scheduler)
```powershell
schtasks /Create /TN "WSUS Top Error Computers" ^
  /TR "powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Scripts\Top-ErrorComputers.ps1" ^
  /SC DAILY /ST 02:00 /RU SYSTEM /RL HIGHEST /F
```

