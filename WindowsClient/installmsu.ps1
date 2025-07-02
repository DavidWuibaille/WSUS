# MSU Prerequisite Check and Install Script

$LogPath = "C:\Windows\Temp\MSU_Install.log"

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogPath -Value "$timestamp $Message"
    Write-Host $Message
}

# Check 1: Reboot pending
$RebootRegKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
if (Test-Path $RebootRegKey) {
    Write-Log "Pending reboot detected."
    exit 101
} else {
    Write-Log "No pending reboot."
}

# Check 3: Free space on C:
$minFreeGB = 5
$drive = Get-PSDrive -Name C
if ($null -eq $drive -or ($drive.Free/1GB) -lt $minFreeGB) {
    Write-Log "Insufficient free space on C:. Required: ${minFreeGB}GB"
    exit 103
} else {
    Write-Log ("Sufficient free space on C:. Free: {0:N2}GB" -f ($drive.Free/1GB))
}

# MSU download info
$MSUFile = "windows10.0-kb5060531-x64.msu"
$MSUUrl = "https://catalog.s.download.windowsupdate.com/c/msdownload/update/software/secu/2025/06/windows10.0-kb5060531-x64_83789c3b9350e10e207370622c4ef54dd685ee02.msu"
$ScriptDir = "c:\windows\temp"
$MSUPath = Join-Path $ScriptDir $MSUFile

# Always delete the MSU file before download
if (Test-Path $MSUPath) {
    Write-Log "Deleting existing MSU file: $MSUPath"
    Remove-Item -Path $MSUPath -Force -ErrorAction SilentlyContinue
}

try {
    Write-Log "Downloading MSU from $MSUUrl using System.Net.WebClient"
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile($MSUUrl, $MSUPath)
    $sw.Stop()
    $downloadTime = "{0:N2}" -f $sw.Elapsed.TotalSeconds

    if (-not (Test-Path $MSUPath)) {
        Write-Log "Failed to download MSU (file not found after download)"
        exit 104
    } else {
        Write-Log "Download completed: $MSUPath"
        Write-Log "Download time: $downloadTime seconds"
    }
} catch {
    Write-Log "Failed to download MSU with WebClient: $_"
    exit 104
}

Write-Log "Starting installation of $MSUPath"

# Install the MSU silently, no restart
$process = Start-Process -FilePath "wusa.exe" -ArgumentList "`"$MSUPath`" /quiet /norestart" -Wait -PassThru
$exitCode = $process.ExitCode

Write-Log "wusa.exe exit code: $exitCode"

# Return the exit code as the script's own exit code
exit $exitCode
