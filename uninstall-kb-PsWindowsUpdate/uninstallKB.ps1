#Requires -RunAsAdministrator
#Requires -Modules PSWindowsUpdate

param(
    [Parameter(Mandatory)]
    [ValidatePattern('^(?i:KB)?\d+$')]
    [string]$KB,
    [switch]$NoRestart
)

# Normalize input to "KBxxxxxxx"
if ($KB -match '^\d+$') { $KB = "KB$KB" }

try {
    Import-Module PSWindowsUpdate -ErrorAction Stop

    # Query only installed updates matching the KB
    $installed = Get-WindowsUpdate -IsInstalled -KBArticleID $KB -ErrorAction SilentlyContinue

    if (-not $installed) {
        Write-Host "Update $KB not found on this system."
        return
    }

    Write-Host "Found installed update: $KB"
    $removeParams = @{ KBArticleID = $KB; Confirm = $false }
    if ($NoRestart) { $removeParams['NoRestart'] = $true }

    Write-Host "Uninstalling $KB ..."
    Remove-WindowsUpdate @removeParams -ErrorAction Stop
    Write-Host "Uninstall command issued for $KB."
    if (-not $NoRestart) { Write-Host "A restart may be required." }
}
catch {
    Write-Error "Failed to uninstall $KB. $($_.Exception.Message)"
}
