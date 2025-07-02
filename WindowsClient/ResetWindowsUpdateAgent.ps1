$global:LogPath = "C:\Windows\Temp\Wuauserv_Cleanup.log"
$ServiceName = "wuauserv"

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $global:LogPath -Value "$timestamp $Message"
	write-host $Message
}

function Clean-WUClientFolders {
    Write-Log "Cleaning up Windows Update client folders"
    $windir = $env:WINDIR
    $WUDownload = Join-Path $windir "SoftwareDistribution\Download"
    $WUDataStore = Join-Path $windir "SoftwareDistribution\Datastore"

    if (Test-Path $WUDownload) {
        try {
            Remove-Item $WUDownload -Recurse -Force
            Write-Log "Deleted $WUDownload"
        } catch {
            Write-Log ("Failed to delete $WUDownload")
        }
    }
    if (Test-Path $WUDataStore) {
        try {
            Remove-Item $WUDataStore -Recurse -Force
            Write-Log "Deleted $WUDataStore"
        } catch {
            Write-Log ("Failed to delete $WUDataStore")
        }
    }
}

try {
    Write-Log "Stopping $ServiceName"
    Stop-Service -Name $ServiceName -Force -ErrorAction Stop
    Start-Sleep -Seconds 3
} catch {
    Write-Log ("Failed to stop $ServiceName")
}

Clean-WUClientFolders

try {
    Write-Log "Starting $ServiceName"
    Start-Service -Name $ServiceName -ErrorAction Stop
    Write-Log "$ServiceName started"
} catch {
    Write-Log ("Failed to start $ServiceName")
}
