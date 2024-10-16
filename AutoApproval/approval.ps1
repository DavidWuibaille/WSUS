
$SyncApprovals = @(
    # Synchronisation des groupes TESTERS vers PILOT
    @{
        "Source"  = "Pilot"  # Groupe source : TESTERS
        "Target"  = "Global1"    # Groupe cible : PILOT
        "MinDays" = 5          # Nombre de jours minimum avant la synchronisation
    },
    
    # Synchronisation des groupes PILOT vers PROD
    @{
        "Source"  = "Global1"    # Groupe source : PILOT
        "Target"  = "Global2"     # Groupe cible : PROD
        "MinDays" = 5          # Nombre de jours minimum avant la synchronisation
    }
)

$logFolder = "C:\logs"
$maxLogs = 60


# Check if the folder exists, create it if it doesn't
If (-not (Test-Path $logFolder)) {
    # Create the folder if it does not exist
    New-Item -Path $logFolder -ItemType Directory
    Write-Host "The directory $logFolder has been created."
} else {
    Write-Host "The directory $logFolder already exists."
}

# Limit the number of log files
$logFiles = Get-ChildItem -Path $logFolder -Filter "WSUS-ManageApprovals*.log" | Sort-Object LastWriteTime -Descending
if ($logFiles.Count -gt $maxLogs) {
    # Remove old log files if the count exceeds the max limit
    $logFiles | Select-Object -Skip $maxLogs | Remove-Item -Force
}

# ----------------- Log Files ----------------------
$logFile = Join-Path $logFolder ("WSUS-ManageApprovals" + (Get-Date -format "yyyyMMdd-HHmmss") + ".log")

# ----------------- Connect to WSUS server ----------------
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

# ----------------- Start synchronization ----------------
Try {
    $subscription.StartSynchronization()
    Write-Output "Synchronization successfully started." | Add-Content -Path $logFile
} Catch {
    Write-Output "Error during WSUS synchronization: $_" | Add-Content -Path $logFile
    Exit
}

# ----------------- Manage updates ----------------------
$workingUpdates = $updates | Where-Object { -not $_.IsDeclined }
Foreach ($update in $workingUpdates) {   
    # Accept license agreement if required
    If ($update.RequiresLicenseAgreementAcceptance) { 
        $update.AcceptLicenseAgreement() 
        Write-Output "License accepted for: $($update.Title)" | Add-Content -Path $logFile
    }
}

# ----------------- Approve updates ------------------
Write-Output "********** Approve KB **********" | Add-Content -Path $logFile
Foreach ($update in $workingUpdates) {
    $approvals = $update.GetUpdateApprovals()
    Foreach ($syncApproval in $SyncApprovals) {
        $sourceGroup = $targetGroups | Where-Object { $_.Name -eq $syncApproval.Source }
        
        # Ensure source group exists and action is set to "Install"
        If ($sourceGroup) {
            $sourceApproval = $approvals | Where-Object { $_.ComputerTargetGroupId -eq $sourceGroup.ID }
            If ($sourceApproval -and $($sourceApproval.Action) -eq "Install") {
                # Check if enough days have passed
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

# ----------------- Disable superseded updates ------------------
Write-Output "********** Disable Superseded Updates **********" | Add-Content -Path $logFile
$workingUpdates = $workingUpdates | Where-Object { $_.IsSuperseded }
Foreach ($update in $workingUpdates) {
    Write-Output "$($update.Title)" | Add-Content -Path $logFile
    
    # Find updates that supersede the current update
    Foreach ($Supersede in $update.GetRelatedUpdates([Microsoft.UpdateServices.Administration.UpdateRelationship]::UpdatesThatSupersedeThisUpdate)) {
        Write-Output "----- Replaced By: $($Supersede.Title)" | Add-Content -Path $logFile
        $approvals = $Supersede.GetUpdateApprovals()
        
        # Check if update is installed on target groups and decline it if needed
        Foreach ($approval in $approvals) {
            Foreach ($targetGroup in $targetGroups) {
                If (($targetGroup.Id -eq $approval.ComputerTargetGroupId) -and ($($approval.Action) -eq "Install")) {
                    Write-Output "---------- $($targetGroup.Name)" | Add-Content -Path $logFile
                    if ($($targetGroup.Name) -like "*GLOBAL*ODD*") {
                        Write-Output "---------- Declining: $($update.Title)" | Add-Content -Path $logFile
                        $update.Decline()
                    }
                }
            }
        }
    }
}

# ----------------- Cleanup WSUS server ----------------
Write-Output "********** Cleanup WSUS **********" | Add-Content -Path $logFile
$cleanupInterface = $wsusServer.GetCleanupManager()
$cleanupScope = New-Object 'Microsoft.UpdateServices.Administration.CleanupScope'
$cleanupScope.DeclineSupersededUpdates = $True
$cleanupScope.DeclineExpiredUpdates = $True
$cleanupScope.CleanupObsoleteComputers = $True
$cleanupScope.CleanupObsoleteUpdates = $True
$cleanupScope.CompressUpdates = $True
$cleanupScope.CleanupUnneededContentFiles = $True
$cleanupInterface.PerformCleanup($cleanupScope)
