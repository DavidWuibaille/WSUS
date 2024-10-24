# ****************************** MODULE IMPORT & INITIALIZATION ******************************

# Import the PSWriteHTML module, used for generating HTML reports
Import-Module -Name PSwriteHTML

# Display a message to inform the user that the script has started
Write-Host "Starting WSUS report generation..."

# Load the Microsoft.UpdateServices.Administration assembly, required for WSUS interaction
[reflection.assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration") | Out-Null

# Get a reference to the local WSUS server
$wsusServer = [Microsoft.UpdateServices.Administration.AdminProxy]::GetUpdateServer()
$updates = $wsusServer.GetUpdates()
$computers = $wsusServer.GetComputerTargets()
$targetGroups = $wsusServer.GetComputerTargetGroups()

# Create a hashtable to map each target group's ID to its name
$groupHashTable = @{ }
$targetGroups | ForEach-Object { $groupHashTable[$_.ID] = $_.Name }

# Inform the user that data has been retrieved successfully
Write-Host "Retrieved WSUS data: Updates, Computers, and Target Groups."


# ****************************** REPORT GENERATION START ******************************

# Generate an HTML report using PSWriteHTML
New-HTML -TitleText 'WSUS Report' {

    # ****************************** COMPUTERS BY TARGET GROUP SECTION ******************************
    
    # Create a generic List object to store the data for the HTML table
    $DataTable = New-Object System.Collections.Generic.List[Object]
    
    # Loop through each target group
    foreach ($group in $targetGroups) {
        # Get the number of computers in this group
        $computersCount = $group.GetComputerTargets().Count
        
        # Only add groups that have computers and exclude 'All Computers' group
        if (($computersCount -gt 0) -and ($group.Name -ne 'All Computers')) {
            # Add a custom object (PSCustomObject) to the DataTable containing the group name and computer count
            $DataTable.Add([PSCustomObject]@{
                TargetName = $group.Name   # Name of the target group
                Total = $computersCount    # Total number of computers in this group
            })
        }
    }

    # Inform the user that the data table has been populated
    Write-Host "Populated DataTable with computer counts per Target Group."

    # Create an HTML section in the report to display computer counts by target group
    New-HTMLSection -HeaderText 'Computers By TargetGroup' {
        # First part: Data table
        New-HTMLpanel {
            New-HTMLTable -DataTable $DataTable -HideFooter -DataTableID 'IDtargetGroup' {
                # Adding some interaction events for the table (not fully detailed here)
                New-TableEvent -ID 'AllComputertargetGroup' -SourceColumnID 0 -TargetColumnId 0
            }
        }

        # Second part: Pie chart displaying the distribution of computers by target group
        New-HTMLpanel {
            New-HTMLChart {
                # Add a toolbar to allow chart download
                New-ChartToolbar -Download
                
                # Create a pie chart for each target group
                foreach ($Object in $DataTable) {
                    New-ChartPie -Name $Object.TargetName -Value $Object.Total
                }
            }
        }
    }

    # ****************************** COMPUTER LIST SECTION ******************************

    # Create a list of computers grouped by their target groups (excluding 'All Computers')
    $ListeComputersWSUS = @()
    foreach ($computer in $computers) {
        $targetGroupsC = $computer.GetComputerTargetGroups()
        foreach ($targetGroup in $targetGroupsC) {
            if ($targetGroup.Name -ne "All Computers") {
                $ListeComputersWSUS += [PSCustomObject]@{
                    TargetName = $targetGroup.Name
                    ComputerName = $computer.FullDomainName
                }
            }
        }
    }

    # Create a hidden section that lists all computers by target group
    New-HTMLSection -HeaderText 'Computers' -Invisible {
        New-HTMLTable -DataTable $ListeComputersWSUS -DataTableID 'AllComputertargetGroup' -HideFooter    
    }


    # ****************************** DEPLOYMENT STATUS OF KB UPDATES ******************************

    $DateNow = Get-Date
    $ListeKB = @()
    $MaxDaysReport = 90

    foreach ($update in $updates) {
        foreach ($approval in $update.GetUpdateApprovals()) {
            foreach ($targetGroup in $targetGroups) {
                if ($targetGroup.Id -eq $approval.ComputerTargetGroupId) {

                    $DateKB = $approval.goLiveTime
                    $LastChange = New-TimeSpan -Start $DateKB -End $DateNow
                    $ActionType = $approval.Action  # Store action type

                    if ($ActionType -eq "Install") {
                        $KBTitre = $update.Title
                        
                        # Initialize install and missing counts to avoid undefined values
                        $installKB = 0
                        $MissKB = 0
                        
                        # We are already in a foreach for the $update, so no need to search again
                        $ResultKBs = $update.GetSummaryPerComputerTargetGroup()
                        foreach ($ResultKB in $ResultKBs) {
                            $groupName = $groupHashTable[$($ResultKB.ComputerTargetGroupId)]

                            if ($($targetGroup.Name) -eq $groupName) {
                                # Calculate installed and missing counts
                                $installKB = $($ResultKB.InstalledCount) + $($ResultKB.InstalledPendingRebootCount)
                                $MissKB    = $($ResultKB.UnknownCount)   + $($ResultKB.NotInstalledCount) + $($ResultKB.DownloadedCount) + $($ResultKB.FailedCount)
                            }
                        }

						# Only add information to the list if both installKB and MissKB are not equal to 0
						# Exclude titles with 'ARM64', 'Service Stack Update', and 'KB4499728'
						if (($installKB -ne 0 -or $MissKB -ne 0) -and 
							($KBTitre -notmatch "ARM64") -and 
							($KBTitre -notmatch "Servicing Stack Update") -and 
							($KBTitre -notmatch "Flash Player") -and 
							($KBTitre -notlike "*KB4470788*") -and 
							($KBTitre -notlike "*KB4499728*")) {

							$ListeKB += [PSCustomObject]@{
								KBTitre    = $KBTitre
								KBGroup    = $targetGroup.Name
								KBChang    = $LastChange.Days
								ActionType = $ActionType  # Add action type to the object
								installKB  = $installKB
								MissKB     = $MissKB
							}
						}
                    }
                }
            }
        }
    }

    # Sort the list by change date and KB title
    $ListeKB = $ListeKB | Sort-Object KBChang, KBTitre

    # Get unique KB titles
    $ListeKBunique = $ListeKB | Select-Object -Unique KBTitre


    # ****************************** GROUP KB DATA AND CREATE CHARTS ******************************

    $groupedByTitle = @{ }

    foreach ($Object in $ListeKB) {
        if (-not $groupedByTitle.ContainsKey($Object.KBTitre)) {
            $groupedByTitle[$Object.KBTitre] = @()
        }
        $groupedByTitle[$Object.KBTitre] += $Object
    }

    foreach ($Title in $groupedByTitle.Keys) {
        New-HTMLSection -HeaderText $Title {
            New-HTMLChart -Title $Title -TitleAlignment center {
                foreach ($Object in $groupedByTitle[$Title]) {
                    $ShortGroupeName = $($Object.KBGroup)
                    New-ChartTimeLine -DateFrom $(Get-Date).AddDays(0 - $($Object.KBChang) - 1) -DateTo $(Get-Date).AddDays(0) -Name $ShortGroupeName
                }
            }
        }

        New-HTMLSection -HeaderText 'Computers' -Invisible {
            foreach ($Object in $groupedByTitle[$Title]) {
                New-HTMLpanel {
                    New-HTMLChart -Title $($Object.KBGroup) {
                        New-ChartLegend -Name "Installed", "Missing" -Color Green, Red
                        New-ChartDonut -Name "Installed" -Value $($Object.installKB)
                        New-ChartDonut -Name "Missing" -Value $($Object.MissKB)
                    }
                }
            }
        }
		

		# ------------------------- Status KB and Computers -------------------------
		# ------------- Status KB et ordinateurs
		$updateScope2 = New-Object Microsoft.UpdateServices.Administration.UpdateScope
		$updateScope2.ApprovedStates = [Microsoft.UpdateServices.Administration.ApprovedStates]::LatestRevisionApproved
		$updateScope2.UpdateApprovalActions = [Microsoft.UpdateServices.Administration.UpdateApprovalActions]::Install
		$updateScope2.UpdateSources = [Microsoft.UpdateServices.Administration.UpdateSources]::MicrosoftUpdate
		$updateScope2.ExcludedInstallationStates = @('NotApplicable', 'Installed', 'InstalledPendingReboot')

		# Get all computer targets from the WSUS server
		$allComputers = $wsusServer.GetComputerTargets()
		$resultsComputerStatus = @()
		# Iterate over each computer
		foreach ($computer in $allComputers) {
			$updatelist = $computer.GetUpdateInstallationInfoPerUpdate($updateScope2)

			foreach ($update in $updatelist) {
				$updateInfo = $update.GetUpdate()
				$approvalGroup = $update.GetUpdateApprovalTargetGroup().Name
				if ($approvalGroup -ne "All Computers" -and $updateInfo.IsApproved -eq $true) {
					$resultsComputerStatus += [pscustomobject][Ordered]@{
						ComputerName = $computer.FullDomainName
						Status = $update.UpdateInstallationState
						ApprovalTargetGroup = $approvalGroup
						Approved = $updateInfo.IsApproved
						Title = $updateInfo.Title
					}
				}
			}
		}

            New-HTMLSection -HeaderText 'Cumputers' -Invisible {
                    foreach ($Object in $groupedByTitle[$Title]) {
                        New-HTMLpanel {
                            $specificTitles = $resultsComputerStatus | Where-Object { ($_.Title -like "*$Title*") -and ($_.ApprovalTargetGroup -like "*$($Object.KBGroup)*") } | Select-Object -Property ComputerName, Status
                            New-HTMLTable -DataTable $specificTitles  -HideFooter -HideButtons
                        }
                    }
            } 






		
		
    }


    # ****************************** COMPUTERS IN ERROR SECTION ******************************

    # Initialize variables for tracking computers in error
    $computersInError = @()
    $updateScope = New-Object Microsoft.UpdateServices.Administration.UpdateScope
    $updateScope.IncludedInstallationStates = 'Failed'
    $computerScope = New-Object Microsoft.UpdateServices.Administration.ComputerTargetScope
    $computerScope.IncludedInstallationStates = 'Failed'
    $GroupFailHash = @{ }
    $ComputerHash = @{ }
    $UpdateHash = @{ }

    # Get computers that have failed updates and gather details
    $computersInError = $wsusServer.GetComputerTargets($computerScope) | ForEach-Object {
        $Computername = $_.FullDomainName
        $Update = ($_.GetUpdateInstallationInfoPerUpdate($updateScope) | ForEach-Object {
            $Update = $_.GetUpdate()
            $Update.title
            $ComputerHash[$Computername] += ,$Update.title
            $UpdateHash[$Update.title] += ,$Computername
        }) -join ', '

        If ($Update) {
            $TempTargetGroups = ($_.GetComputerTargetGroups() | Select-Object -ExpandProperty Name)
            $TempTargetGroups | ForEach-Object {
                $GroupFailHash[$_]++
            }
            [pscustomobject]@{
                Computername = $_.FullDomainName
                TargetGroups = $TempTargetGroups -join ', '
                Updates = $Update
            }
        }
    } | Sort-Object Computername

    # Create a section to display computers with failed updates
    New-HTMLSection -HeaderText 'Computers in ERROR' {
        New-HTMLTable -DataTable $computersInError -DataTableID 'NewIDtoSearchInChartERR' -HideFooter
    }

    # ****************************** FOOTER SECTION ******************************
    
    # Add a footer to the report with the date and time the report was generated (in GMT)
    New-HTMLFooter {
        New-HTMLText -Text "Date of this report (GMT time) $(Get-Date)" -Color Blue -Alignment center
    }

} -FilePath "C:\exploit\report\default.htm" -Online  # Specify the output path for the HTML report


# ****************************** REPORT GENERATION COMPLETE ******************************

# Inform the user that the report has been successfully created
Write-Host "WSUS report has been generated successfully at C:\exploit\report\default.htm"
