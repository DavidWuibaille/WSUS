#Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'

# ****************************** MODULE IMPORT & INITIALIZATION ******************************
# HTML reporting module
Import-Module -Name PSWriteHTML -ErrorAction Stop

Write-Host "Starting WSUS report generation..."

# Load WSUS admin assembly explicitly (no deprecated LoadWithPartialName)
$wsusDll = "$env:ProgramFiles\Update Services\Tools\Microsoft.UpdateServices.Administration.dll"
if (Test-Path $wsusDll) { Add-Type -Path $wsusDll } else { throw "WSUS Admin DLL not found: $wsusDll" }

# Connect to local WSUS and pull data
$wsusServer   = [Microsoft.UpdateServices.Administration.AdminProxy]::GetUpdateServer()
$updates      = $wsusServer.GetUpdates()
$computers    = $wsusServer.GetComputerTargets()
$targetGroups = $wsusServer.GetComputerTargetGroups()

# Map groupId -> groupName for quick lookups
$groupHashTable = @{}
$targetGroups | ForEach-Object { $groupHashTable[$_.ID] = $_.Name }

Write-Host "Retrieved WSUS data: Updates, Computers, and Target Groups."

# Ensure output folder exists
$outFile = "C:\exploit\report\default.htm"
$outDir  = Split-Path $outFile -Parent
if (-not (Test-Path $outDir)) { New-Item -Path $outDir -ItemType Directory -Force | Out-Null }

# ****************************** REPORT GENERATION START ******************************
New-HTML -TitleText 'WSUS Report' {

    # ****************************** COMPUTERS BY TARGET GROUP ******************************
    # Build a simple dataset: group name + computer count (skip 'All Computers')
    $DataTable = New-Object System.Collections.Generic.List[Object]
    foreach ($group in $targetGroups) {
        $computersCount = $group.GetComputerTargets().Count
        if ($computersCount -gt 0 -and $group.Name -ne 'All Computers') {
            $DataTable.Add([PSCustomObject]@{
                TargetName = $group.Name
                Total      = $computersCount
            })
        }
    }
    Write-Host "Populated DataTable with computer counts per Target Group."

    New-HTMLSection -HeaderText 'Computers By TargetGroup' {
        # Table
        New-HTMLPanel {
            New-HTMLTable -DataTable $DataTable -HideFooter -DataTableID 'IDtargetGroup' {
                # Bind events to the correct table ID
                New-TableEvent -ID 'IDtargetGroup' -SourceColumnID 0 -TargetColumnId 0
            }
        }
        # Pie chart per group
        New-HTMLPanel {
            New-HTMLChart {
                New-ChartToolbar -Download
                foreach ($row in $DataTable) { New-ChartPie -Name $row.TargetName -Value $row.Total }
            }
        }
    }

    # ****************************** COMPUTER LIST (HIDDEN) ******************************
    $ListeComputersWSUS = @()
    foreach ($computer in $computers) {
        foreach ($tg in $computer.GetComputerTargetGroups()) {
            if ($tg.Name -ne 'All Computers') {
                $ListeComputersWSUS += [PSCustomObject]@{
                    TargetName   = $tg.Name
                    ComputerName = $computer.FullDomainName
                }
            }
        }
    }
    New-HTMLSection -HeaderText 'Computers' -Invisible {
        New-HTMLTable -DataTable $ListeComputersWSUS -DataTableID 'AllComputertargetGroup' -HideFooter
    }

    # ****************************** DEPLOYMENT STATUS OF KB UPDATES ******************************
    $DateNow   = Get-Date
    $ListeKB   = @()
    $MaxDaysReport = 90  # (kept for future filtering if needed)

    foreach ($update in $updates) {
        foreach ($approval in $update.GetUpdateApprovals()) {
            foreach ($tg in $targetGroups) {
                if ($tg.Id -eq $approval.ComputerTargetGroupId) {
                    $DateKB   = $approval.GoLiveTime
                    $LastChange = New-TimeSpan -Start $DateKB -End $DateNow
                    $ActionType = $approval.Action

                    if ($ActionType -eq 'Install') {
                        $KBTitre = $update.Title
                        $installKB = 0; $MissKB = 0

                        # Summaries per group for this update
                        foreach ($sum in $update.GetSummaryPerComputerTargetGroup()) {
                            $groupName = $groupHashTable[$sum.ComputerTargetGroupId]
                            if ($tg.Name -eq $groupName) {
                                $installKB = $sum.InstalledCount + $sum.InstalledPendingRebootCount
                                $MissKB    = $sum.UnknownCount + $sum.NotInstalledCount + $sum.DownloadedCount + $sum.FailedCount
                            }
                        }

                        # Keep only meaningful KBs (exclude ARM64, SSU, Flash, specific KBs)
                        if (($installKB -ne 0 -or $MissKB -ne 0) -and
                            ($KBTitre -notmatch 'ARM64') -and
                            ($KBTitre -notmatch 'Servicing Stack Update') -and
                            ($KBTitre -notmatch 'Flash Player') -and
                            ($KBTitre -notlike '*KB4470788*') -and
                            ($KBTitre -notlike '*KB4499728*')) {
                            $ListeKB += [PSCustomObject]@{
                                KBTitre    = $KBTitre
                                KBGroup    = $tg.Name
                                KBChang    = $LastChange.Days
                                ActionType = $ActionType
                                installKB  = $installKB
                                MissKB     = $MissKB
                            }
                        }
                    }
                }
            }
        }
    }

    # Sort by age then title; get unique titles for chart grouping
    $ListeKB       = $ListeKB | Sort-Object KBChang, KBTitre
    $groupedByTitle = @{}
    foreach ($o in $ListeKB) {
        if (-not $groupedByTitle.ContainsKey($o.KBTitre)) { $groupedByTitle[$o.KBTitre] = @() }
        $groupedByTitle[$o.KBTitre] += $o
    }

    foreach ($Title in $groupedByTitle.Keys) {
        # Timeline per group (how many days since approval)
        New-HTMLSection -HeaderText $Title {
            New-HTMLChart -Title $Title -TitleAlignment center {
                foreach ($o in $groupedByTitle[$Title]) {
                    New-ChartTimeline -DateFrom (Get-Date).AddDays(-$o.KBChang - 1) -DateTo (Get-Date) -Name $o.KBGroup
                }
            }
        }

        # Donut charts (Installed vs Missing) per group – hidden
        New-HTMLSection -HeaderText 'Computers' -Invisible {
            foreach ($o in $groupedByTitle[$Title]) {
                New-HTMLPanel {
                    New-HTMLChart -Title $o.KBGroup {
                        New-ChartLegend -Name "Installed","Missing" -Color Green,Red
                        New-ChartDonut  -Name "Installed" -Value $o.installKB
                        New-ChartDonut  -Name "Missing"  -Value $o.MissKB
                    }
                }
            }
        }

        # ------------------------- KB and Computers status table (hidden) -------------------------
        $updateScope2 = New-Object Microsoft.UpdateServices.Administration.UpdateScope
        $updateScope2.ApprovedStates            = [Microsoft.UpdateServices.Administration.ApprovedStates]::LatestRevisionApproved
        $updateScope2.UpdateApprovalActions     = [Microsoft.UpdateServices.Administration.UpdateApprovalActions]::Install
        $updateScope2.UpdateSources             = [Microsoft.UpdateServices.Administration.UpdateSources]::MicrosoftUpdate
        $updateScope2.ExcludedInstallationStates = @('NotApplicable','Installed','InstalledPendingReboot')

        $allComputers = $wsusServer.GetComputerTargets()
        $resultsComputerStatus = @()

        foreach ($pc in $allComputers) {
            $updatelist = $pc.GetUpdateInstallationInfoPerUpdate($updateScope2)
            foreach ($ui in $updatelist) {
                $updInfo = $ui.GetUpdate()
                $approvalGroup = $ui.GetUpdateApprovalTargetGroup().Name
                if ($approvalGroup -ne 'All Computers' -and $updInfo.IsApproved) {
                    $resultsComputerStatus += [pscustomobject][Ordered]@{
                        ComputerName       = $pc.FullDomainName
                        Status             = $ui.UpdateInstallationState
                        ApprovalTargetGroup= $approvalGroup
                        Approved           = $updInfo.IsApproved
                        Title              = $updInfo.Title
                    }
                }
            }
        }

        New-HTMLSection -HeaderText 'Computers' -Invisible {
            foreach ($o in $groupedByTitle[$Title]) {
                New-HTMLPanel {
                    $specific = $resultsComputerStatus |
                        Where-Object { $_.Title -like "*$Title*" -and $_.ApprovalTargetGroup -like "*$($o.KBGroup)*" } |
                        Select-Object ComputerName, Status
                    New-HTMLTable -DataTable $specific -HideFooter -HideButtons
                }
            }
        }
    }

    # ****************************** COMPUTERS IN ERROR ******************************
    $computersInError = @()
    $updateScope = New-Object Microsoft.UpdateServices.Administration.UpdateScope
    $updateScope.IncludedInstallationStates = 'Failed'
    $computerScope = New-Object Microsoft.UpdateServices.Administration.ComputerTargetScope
    $computerScope.IncludedInstallationStates = 'Failed'

    $computersInError = $wsusServer.GetComputerTargets($computerScope) | ForEach-Object {
        $compName = $_.FullDomainName
        $failedTitles = ($_.GetUpdateInstallationInfoPerUpdate($updateScope) | ForEach-Object {
            $_.GetUpdate().Title
        }) -join ', '
        if ($failedTitles) {
            [pscustomobject]@{
                Computername = $compName
                TargetGroups = ($_.GetComputerTargetGroups() | Select-Object -ExpandProperty Name) -join ', '
                Updates      = $failedTitles
            }
        }
    } | Sort-Object Computername

    New-HTMLSection -HeaderText 'Computers in ERROR' {
        New-HTMLTable -DataTable $computersInError -DataTableID 'NewIDtoSearchInChartERR' -HideFooter
    }

    # ****************************** FOOTER ******************************
    New-HTMLFooter {
        New-HTMLText -Text ("Report generated (GMT): {0:u}" -f (Get-Date).ToUniversalTime()) -Color Blue -Alignment center
    }

} -FilePath $outFile -Online

Write-Host "WSUS report has been generated successfully at $outFile"
