# Script to stop update-related services, rename folders, and restart services

$LogPath = "C:\Windows\Temp\WUA_Reset.log"
$Services = @("wuauserv", "cryptSvc", "bits", "msiserver")
$SoftwareDistribution = "C:\Windows\SoftwareDistribution"
$SoftwareDistributionOld = "C:\Windows\SoftwareDistribution.old"
$Catroot2 = "C:\Windows\System32\catroot2"
$Catroot2Old = "C:\Windows\System32\catroot2.old"

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogPath -Value "$timestamp $Message"
}

# Stop services
foreach ($svc in $Services) {
    try {
        Write-Log "Stopping service: $svc"
        Stop-Service -Name $svc -Force -ErrorAction Stop
    } catch {
        Write-Log "Failed to stop service $svc: $_"
    }
}

Start-Sleep -Seconds 3

# Rename SoftwareDistribution folder
if (Test-Path $SoftwareDistribution) {
    try {
        if (Test-Path $SoftwareDistributionOld) {
            Remove-Item -Path $SoftwareDistributionOld -Recurse -Force
            Write-Log "Removed existing $SoftwareDistributionOld"
        }
        Rename-Item -Path $SoftwareDistribution -NewName "SoftwareDistribution.old"
        Write-Log "Renamed $SoftwareDistribution to $SoftwareDistributionOld"
    } catch {
        Write-Log "Failed to rename $SoftwareDistribution: $_"
    }
}

# Rename catroot2 folder
if (Test-Path $Catroot2) {
    try {
        if (Test-Path $Catroot2Old) {
            Remove-Item -Path $Catroot2Old -Recurse -Force
            Write-Log "Removed existing $Catroot2Old"
        }
        Rename-Item -Path $Catroot2 -NewName "catroot2.old"
        Write-Log "Renamed $Catroot2 to $Catroot2Old"
    } catch {
        Write-Log "Failed to rename $Catroot2: $_"
    }
}

Start-Sleep -Seconds 2

# Start services
foreach ($svc in $Services) {
    try {
        Write-Log "Starting service: $svc"
        Start-Service -Name $svc -ErrorAction Stop
    } catch {
        Write-Log "Failed to start service $svc: $_"
    }
}

Write-Log "Script completed."
