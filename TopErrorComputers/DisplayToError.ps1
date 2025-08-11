#Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'
 
# ---- Parameters ----
$Days   = 7         # time window for error events
$Top    = 10        # top N computers by error count
$OutCsv = "$PSScriptRoot\WSUS_FailedComputers_{0:yyyyMMdd}.csv" -f (Get-Date)
 
# ---- Connect to WSUS (module if available, else DLL) ----
if (Get-Module -ListAvailable UpdateServices) {
    Import-Module UpdateServices -ErrorAction Stop
    $wsus = Get-WsusServer
} else {
    $dll = "$env:ProgramFiles\Update Services\Tools\Microsoft.UpdateServices.Administration.dll"
    if (-not (Test-Path $dll)) { throw "WSUS Admin DLL not found: $dll" }
    Add-Type -Path $dll
    $wsus = [Microsoft.UpdateServices.Administration.AdminProxy]::GetUpdateServer()
}
 
# ---- Pull error events in the time window ----
$from = (Get-Date).Date.AddDays(-[int]$Days)
$to   = (Get-Date).Date
$events = $wsus.GetUpdateEventHistory($from, $to) |
  Where-Object { $_.IsError -and $_.ComputerId -ne [Guid]::Empty }
 
# ---- Aggregate per computer and take Top N ----
$allComputers = $wsus.GetComputerTargets()
$compById = @{}; foreach ($c in $allComputers) { $compById[$c.Id] = $c }
 
$topByCount = $events | Group-Object ComputerId |
  Sort-Object Count -Descending | Select-Object -First $Top
 
$result = foreach ($g in $topByCount) {
  $c = $compById[$g.Name]
  $lastEvt = $events | Where-Object { $_.ComputerId -eq $c.Id } |
             Sort-Object CreationDate -Descending | Select-Object -First 1
  [pscustomobject]@{
    ComputerName = $c.FullDomainName
    IPAddress    = $c.IPAddress
    Errors       = $g.Count
    LastError    = $lastEvt.CreationDate
  }
}
 
# ---- Output: table + CSV ----
$result | Format-Table -AutoSize
$result | Export-Csv -Path $OutCsv -NoTypeInformation -Encoding UTF8
Write-Host "CSV: $OutCsv"
 
# ---- For each top computer, list failed updates (titles) ----
$updScope = New-Object Microsoft.UpdateServices.Administration.UpdateScope
foreach ($item in $result) {
    $pc = $allComputers | Where-Object { $_.FullDomainName -eq $item.ComputerName }
    if (-not $pc) { continue }
    $failed = $pc.GetUpdateInstallationInfoPerUpdate($updScope) |
              Where-Object UpdateInstallationState -EQ 'Failed'
    if ($failed) {
        Write-Host "`n$($item.ComputerName) — failed updates:"
        foreach ($u in $failed) { ($wsus.GetUpdate($u.UpdateId).Title) | ForEach-Object { Write-Host " - $_" } }
    }
}