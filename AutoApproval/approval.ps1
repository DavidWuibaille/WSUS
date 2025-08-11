$SyncApprovals = @(
    # Sync TESTERS -> PILOT
    @{
        "Source"  = "Pilot"      # Source group: TESTERS
        "Target"  = "Global1"    # Target group: PILOT
        "MinDays" = 5            # Minimum number of days before synchronization
    },
    
    # Sync PILOT -> PROD
    @{
        "Source"  = "Global1"    # Source group: PILOT
        "Target"  = "Global2"    # Target group: PROD
        "MinDays" = 5            # Minimum number of days before synchronization
    }
)

$logFolder = "C:\logs"
$maxLogs = 60

# Ensure the log folder exists (create if missing)
If (-not (Test-Path $logFolder)) {
    New-Item -Path $logFolder -ItemType Directory
    Write-Host "The directory $logFolder has been created."
} else {
    Write-Host "The directory $logFolder already exists."
}

# Limit the number of log files (keep the most recent $maxLogs)
$logFiles = Get-ChildItem -Path $logFolder -Filter "WSUS-ManageApprovals*.log" | Sort-Object LastWriteTime -Descending
if ($logFiles.Count -gt $maxLogs) {
    $logFiles | Select-Object -Skip $maxLogs | Remove-Item -Force
}

# Build current log file path
$logFile = Join-Path $logFolder ("WSUS-ManageApprovals" + (Get-Date -format "yyyyMMdd-HHmmss") + ".log")

# Connect to the WSUS server
Try {
    [reflection.assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration") | Out-Null
    $wsusServer = [Microsoft.UpdateServices.Administration.AdminProxy]::GetUpdateServer()
    $subscription = $wsusServer.GetSubscription()
    $wsusServerConfig = $wsusServer.GetConfiguration()
    $targetGroups = $wsusServer.GetComputerTargetGroups()
    $updates = $wsusServer.GetUpdates()
} Catch {
    Write-Output "Error connecting to the WSUS server: $_" | Add-Content -Path $logFile
    Exit
}

# Start a WSUS synchronization (non-blocking)
Try {
    $subscription.StartSynchronization()
    Write-Output "Synchronization successfully started." | Add-Content -Path $logFile
} Catch {
    Write-Output "Error during WSUS synchronization: $_" | Add-Content -Path $logFile
    Exit
}

# Filter working updates (exclude declined) and accept EULAs if needed
$workingUpdates = $updates | Where-Object { -not $_.IsDeclined }
Foreach ($update in $workingUpdates) {   
    # Accept license agreement if required
    If ($update.RequiresLicenseAgreementAcceptance) { 
        $update.AcceptLicenseAgreement() 
        Write-Output "License accepted for: $($update.Title)" | Add-Content -Path $logFile
    }
}

# Approve updates to target groups after MinDays since source approval GoLiveTime
Write-Output "********** Approve KB **********" | Add-Content -Path $logFile
Foreach ($update in $workingUpdates) {
    $approvals = $update.GetUpdateApprovals()
    Foreach ($syncApproval in $SyncApprovals) {
        $sourceGroup = $targetGroups | Where-Object { $_.Name -eq $syncApproval.Source }
        
        # Ensure source group exists and action is Install
        If ($sourceGroup) {
            $sourceApproval = $approvals | Where-Object { $_.ComputerTargetGroupId -eq $sourceGroup.ID }
            If ($sourceApproval -and $($sourceApproval.Action) -eq "Install") {
                # Check if enough days have passed since GoLiveTime
                $LastChangeKB = (New-TimeSpan -Start $sourceApproval.GoLiveTime -End (Get-Date)).Days
                If ($LastChangeKB -ge $syncApproval.MinDays) {
                    $targetGroup = $targetGroups | Where-Object { $_.Name -eq $syncApproval.Target }
                    $targetApproval = $approvals | Where-Object { $_.ComputerTargetGroupId -eq $targetGroup.ID }
                    
                    # Approve the update if it's not already approved for installation
                    If ($($targetApproval.Action) -ne "Install") {
                        Write-Output "Approving: $($syncApproval.Target) => $($update.Title) - $LastChangeKB days" | Add-Content -Path $logFile
                        $update.Approve("Install", $targetGroup) | Out-Null
                    }
                }
            }
        } else {
            Write-Output "Source group $($syncApproval.Source) not found." | Add-Content -Path $logFile
        }
    }
}

# Decline superseded updates if a superseding one is installed for the expected target groups
Write-Output "********** Disable Superseded Updates **********" | Add-Content -Path $logFile
$workingUpdates = $workingUpdates | Where-Object { $_.IsSuperseded }
Foreach ($update in $workingUpdates) {
    Write-Output "$($update.Title)" | Add-Content -Path $logFile
    
    # Find updates that supersede the current update
    Foreach ($Supersede in $update.GetRelatedUpdates([Microsoft.UpdateServices.Administration.UpdateRelationship]::UpdatesThatSupersedeThisUpdate)) {
        Write-Output "----- Replaced By: $($Supersede.Title)" | Add-Content -Path $logFile
        $approvals = $Supersede.GetUpdateApprovals()
        
        # If a superseding update is approved for Install in Global2, decline the superseded one
        Foreach ($approval in $approvals) {
            Foreach ($targetGroup in $targetGroups) {
                If (($targetGroup.Id -eq $approval.ComputerTargetGroupId) -and ($($approval.Action) -eq "Install")) {
                    Write-Output "---------- $($targetGroup.Name)" | Add-Content -Path $logFile
                    if ($($targetGroup.Name) -eq "Global2") {   # fixed: target group is Global2
                        Write-Output "---------- Declining: $($update.Title)" | Add-Content -Path $logFile
                        $update.Decline()
                    }
                }
            }
        }
    }
}
