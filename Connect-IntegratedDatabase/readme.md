# Connect to WSUS Integrated Database (WID)

Connect locally to the WSUS Windows Internal Database (WID) via the named pipe to run maintenance or reporting against the `SUSDB` database. WID does not allow remote connections—run tools **on the WSUS server** with administrative privileges.

## Prerequisites
- Run on the WSUS server, **elevated** (Run as Administrator).
- One of: SSMS, `sqlcmd`, or the PowerShell `SqlServer` module.
- Pipe (WID on Server 2012+): `\\.\pipe\MICROSOFT##WID\tsql\query`  
  Database: `SUSDB`

## SSMS (GUI)
1. Start SSMS “Run as administrator”.
2. Server type: Database Engine  
   Server name: `\\.\pipe\MICROSOFT##WID\tsql\query`  
   Authentication: Windows Authentication
3. Connect and open a new query window.

Quick smoke test:
```sql
SELECT @@VERSION AS SqlEngineVersion, DB_NAME() AS CurrentDatabase;
SELECT TOP (5) name, create_date FROM sys.tables ORDER BY create_date DESC;
```
## sqlcmd (CLI)
```bat
:: Run locally on the WSUS server (elevated)
sqlcmd -S np:\\.\pipe\MICROSOFT##WID\tsql\query -d SUSDB -E -Q "SELECT TOP (1) GETDATE() AS ConnectedAt;"
```

## PowerShell (Invoke-Sqlcmd)
```PowerShell
Import-Module SqlServer

$Instance = "\\.\pipe\MICROSOFT##WID\tsql\query"
$Database = "SUSDB"

# One-liner test
Invoke-Sqlcmd -ServerInstance $Instance -Database $Database -Query "SELECT TOP (1) GETDATE() AS ConnectedAt;"

# Run a maintenance script
$FileSql = ".\Maintenance.sql"   # e.g., reindex/cleanup queries
Invoke-Sqlcmd -ServerInstance $Instance -Database $Database -InputFile $FileSql
```