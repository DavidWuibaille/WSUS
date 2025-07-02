# MSU Prerequisite Check and Install Script

$LogPath = "C:\Windows\Temp\MSU_Install.log"

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogPath -Value "$timestamp $Message"
}

# Check 1: Reboot pending
$RebootRegKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
if (Test-Path $RebootRegKey) {
    Write-Log "Pending reboot detected."
    exit 101
} else {
    Write-Log "No pending reboot."
}

# Check 2: Windows Update service running
try {
    $wua = Get-Service -Name 'wuauserv'
    if ($wua.Status -ne 'Running') {
        Write-Log "wuauserv service is not running."
        exit 102
    } else {
        Write-Log "wuauserv service is running."
    }
} catch {
    Write-Log "wuauserv service not found: $_"
    exit 102
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

# MSU file name (must be present in script folder)
$MSUFile = "update.msu" # Change as needed
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$MSUPath = Join-Path $ScriptDir $MSUFile

# Check if MSU file exists
if (-not (Test-Path $MSUPath)) {
    Write-Log "MSU file not found: $MSUPath"
    exit 104
}

Write-Log "Starting installation of $MSUPath"

# Install the MSU silently, no restart
$process = Start-Process -FilePath "wusa.exe" -ArgumentList "`"$MSUPath`" /quiet /norestart" -Wait -PassThru
$exitCode = $process.ExitCode

Write-Log "wusa.exe exit code: $exitCode"

# Return the exit code as the script's own exit code
exit $exitCode
