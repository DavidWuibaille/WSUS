# WSUS SUSDB Maintenance (Reindex + Update Stats)

Keep **SUSDB** fast: rebuild/reorganize fragmented indexes, then run `sp_updatestats`. Run off-hours; back up first.

## Requirements
- Admin on the WSUS server.
- Either **SqlServer** PowerShell module (`Install-Module SqlServer`) or **sqlcmd** tools.
- WID instance uses the named pipe: `np:\\.\pipe\MICROSOFT##WID\tsql\query`.

## Quick start
1) Save the SQL script as: `C:\Scripts\WSUSDBMaintenance.sql` (same as in this repo/article).
2) Run one of the following:

```powershell
# PowerShell (SqlServer module) — SQL Server instance
Invoke-Sqlcmd -ServerInstance 'localhost' -Database 'SUSDB' `
  -InputFile C:\Scripts\WSUSDBMaintenance.sql -AbortOnError

# PowerShell (SqlServer module) — WID (local only)
Invoke-Sqlcmd -ServerInstance 'np:\\.\pipe\MICROSOFT##WID\tsql\query' `
  -Database 'SUSDB' -InputFile C:\Scripts\WSUSDBMaintenance.sql -AbortOnError
```

```powershell
# sqlcmd CLI — SQL Server
sqlcmd -S localhost -d SUSDB -i C:\Scripts\WSUSDBMaintenance.sql -b

# sqlcmd CLI — WID (local only)
sqlcmd -S np:\\.\pipe\MICROSOFT##WID\tsql\query -d SUSDB -i C:\Scripts\WSUSDBMaintenance.sql -b
```

## Schedule (optional)
```powershell
schtasks /Create /TN "WSUS DB Maintenance" ^
  /TR "powershell.exe -NoProfile -Command Invoke-Sqlcmd -ServerInstance 'np:\\.\pipe\MICROSOFT##WID\tsql\query' -Database SUSDB -InputFile C:\Scripts\WSUSDBMaintenance.sql -AbortOnError" ^
  /SC MONTHLY /D 1 /ST 02:00 /RU "SYSTEM" /RL HIGHEST /F
```

