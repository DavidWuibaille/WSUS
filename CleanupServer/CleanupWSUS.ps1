#Requires -RunAsAdministrator
[CmdletBinding()]
param(
  [string]$ServerName = 'localhost',
  [int]$Port = 8530,
  [switch]$UseSsl
)

# Load the WSUS admin assembly explicitly if the module isn't present
$wsusDll = "$env:ProgramFiles\Update Services\Tools\Microsoft.UpdateServices.Administration.dll"
if (-not (Get-Module -ListAvailable UpdateServices)) {
    if (Test-Path $wsusDll) { Add-Type -Path $wsusDll } else { throw "WSUS Admin DLL not found: $wsusDll" }
}

try {
    $wsusServer = [Microsoft.UpdateServices.Administration.AdminProxy]::GetUpdateServer($ServerName, [bool]$UseSsl, $Port)
    $cleanupInterface = $wsusServer.GetCleanupManager()
    $cleanupScope = New-Object Microsoft.UpdateServices.Administration.CleanupScope
    $cleanupScope.DeclineSupersededUpdates    = $true
    $cleanupScope.DeclineExpiredUpdates       = $true
    $cleanupScope.CleanupObsoleteComputers    = $true
    $cleanupScope.CleanupObsoleteUpdates      = $true
    $cleanupScope.CompressUpdates             = $true
    $cleanupScope.CleanupUnneededContentFiles = $true

    $cleanupInterface.PerformCleanup($cleanupScope)
    Write-Host "WSUS cleanup completed."
}
catch {
    Write-Error "WSUS cleanup failed: $($_.Exception.Message)"
    exit 1
}
