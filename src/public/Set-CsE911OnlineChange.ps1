using module '..\..\modules\PSClassExtensions\bin\release\PSClassExtensions\PSClassExtensions.psd1'

function Set-CsE911OnlineChange {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ChangeObject[]]
        $PendingChange,

        [Parameter(Mandatory = $false)]
        [string]
        $ExecutionPlanPath
    )
    begin {
        $commandHelper = [PSFunctionHost]::StartNew($PSCmdlet, 'Updating LIS', [E911ModuleState]::Interval)

        Assert-TeamsIsConnected
        function New-ExecutionPlanFile {
            [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
            param (
                [Parameter(Mandatory = $false)]
                [string]
                $ExecutionPlanPath
            )
            if (![string]::IsNullOrEmpty($ExecutionPlanPath)) {
                # validate path is valid here, add header to file
                if (!(Test-Path -Path $ExecutionPlanPath -IsValid)) {
                    $ExecutionPlanPath = ''
                }
                if ((Test-Path -Path $ExecutionPlanPath -PathType Container -ErrorAction SilentlyContinue)) {
                    # get new file name:
                    $ExecutionName = if (!$PSCmdlet.ShouldProcess('Creating Execution Plan File Name')) { 'ExecutionPlan' } else { 'ExecutedCommands' }
                    $Date = '{0:yyyy-MM-dd HH:mm:ss}' -f [DateTime]::Now
                    $FileName = 'E911{0}_{1:yyyyMMdd_HHmmss}.txt' -f $ExecutionName, [DateTime]::Now
                    $ExecutionPlanPath = Join-Path -Path $ExecutionPlanPath -ChildPath $FileName
                }
                try {
                    $ContentParams = @{
                        WhatIf      = $false
                        Path        = $ExecutionPlanPath
                        ErrorAction = 'Stop'
                    }
                    Set-Content -Value '# *******************************************************************************' @ContentParams
                    if (!$PSCmdlet.ShouldProcess('Creating Execution Plan Header')) {
                        Add-Content -Value '# Teams E911 Automation generated execution plan' @ContentParams
                        Add-Content -Value '# The following commands are what the workflow would execute in a live scenario' @ContentParams
                        Add-Content -Value '# These must be executed from a valid MicrosoftTeams PowerShell session' @ContentParams
                        Add-Content -Value '# These commands must be executed in-order in the same PowerShell session' @ContentParams
                    }
                    else {
                        Add-Content -Value '# Teams E911 Automation executed commands' @ContentParams
                        Add-Content -Value "# The following commands are what workflow executed at $Date" @ContentParams
                    }
                    Add-Content -Value '# *******************************************************************************' @ContentParams
                    Add-Content -Value '' @ContentParams
                }
                catch {
                    Write-Warning "file write failed: $($_.Exception.Message)"
                    $ExecutionPlanPath = ''
                }
                if ([string]::IsNullOrEmpty($ExecutionPlanPath)) {
                    Write-Warning "$($ExecutionPlanPath) is not a writeable path, execution plan will not be saved!"
                }
            }
            return $ExecutionPlanPath
        }
        $ExecutionPlanFileCreated = $false
        $LookupsInitialized = $false
        $ProcessedChanges = [Collections.Generic.List[ItemId]]::new()
        $PendingChanges = [Collections.Generic.Dictionary[int, Collections.Generic.List[ChangeObject]]]::new()
        $commandHelper.WriteInformation('Processing changes with 0 dependencies')
    }
    process {
        foreach ($Change in $PendingChange) {
            if ($null -ne $Change.CommandObject -and $Change.CommandObject.HasWarnings()) {
                $commandHelper.WriteVerbose(('{0} has warnings, skipping further processing' -f $Change.Id))
                if ($Change.UpdateType -eq [UpdateType]::Source) {
                    $Change.DependsOn.Clear()
                    $Change.CommandObject | ConvertFrom-Json | Write-Output
                }
                $commandHelper.Update($true, ('{0} Change: {1}' -f $Change.UpdateType, $(if ($Change.UpdateType -eq [UpdateType]::Online) { $Change.ProcessInfo } else { $Change.Id })))
                continue
            }
            if ($Change.DependsOn.Count() -eq 0) {
                if ($Change.UpdateType -eq [UpdateType]::Source) {
                    $commandHelper.WriteVerbose(('{0} is a source change with no needed changes' -f $Change.Id))
                    $Change.CommandObject | ConvertFrom-Json | Write-Output
                    $commandHelper.Update($true, ('{0} Change: {1}' -f $Change.UpdateType, $(if ($Change.UpdateType -eq [UpdateType]::Online) { $Change.ProcessInfo } else { $Change.Id })))
                    continue
                }
                try {
                    if (!$LookupsInitialized) {
                        $LookupsInitialized = $true
                        foreach ($Name in @('Addresses', 'Locations')) {
                            $Declaration = [ScriptBlock]::Create(('${0} = [Collections.Generic.Dictionary[string,object]]@{{}}' -f $Name))
                            $null = Invoke-Command -ScriptBlock $Declaration -NoNewScope -ErrorAction Stop
                            if (![string]::IsNullOrEmpty($ExecutionPlanPath)) {
                                if (!$ExecutionPlanFileCreated) {
                                    $ExecutionPlanPath = New-ExecutionPlanFile -ExecutionPlanPath $ExecutionPlanPath
                                    $ExecutionPlanFileCreated = $true
                                }
                                $Declaration.ToString() | Add-Content -Path $ExecutionPlanPath -WhatIf:$false
                            }
                        }
                    }
                    if ($PSCmdlet.ShouldProcess($Change.ProcessInfo.ToString())) {
                        $null = Invoke-Command -ScriptBlock $Change.ProcessInfo -NoNewScope -ErrorAction Stop
                        [E911ModuleState]::ShouldClearLIS = $true
                    }
                    if (![string]::IsNullOrEmpty($ExecutionPlanPath)) {
                        $Change.ProcessInfo.ToString() | Add-Content -Path $ExecutionPlanPath -WhatIf:$false
                    }
                    $ProcessedChanges.Add($Change.Id)
                    [E911ModuleState]::ShouldClear = $true
                }
                catch {
                    $Change.CommandObject.Warning.Add([WarningType]::OnlineChangeError, "Command: { $($Change.ProcessInfo) } ErrorMessage: $($_.Exception.Message)")
                    $commandHelper.WriteWarning(('Command: {{ {0} }} ErrorMessage: {1}' -f $Change.ProcessInfo, $_.Exception.Message))
                    if (![string]::IsNullOrEmpty($ExecutionPlanPath)) {
                        if (!$ExecutionPlanFileCreated) {
                            $ExecutionPlanPath = New-ExecutionPlanFile -ExecutionPlanPath $ExecutionPlanPath
                            $ExecutionPlanFileCreated = $true
                        }
                        '# COMMAND FAILED! ERROR:' | Add-Content -Path $ExecutionPlanPath -WhatIf:$false
                        "# $($_.Exception.Message -replace "`n","`n# ")" | Add-Content -Path $ExecutionPlanPath -WhatIf:$false
                    }
                }
                $commandHelper.Update($true, ('{0} Change: {1}' -f $Change.UpdateType, $(if ($Change.UpdateType -eq [UpdateType]::Online) { $Change.ProcessInfo } else { $Change.Id })))
                continue
            }
            if (!$PendingChanges.ContainsKey($Change.DependsOn.Count())) {
                $PendingChanges[$Change.DependsOn.Count()] = @()
            }
            [void]$PendingChanges[$Change.DependsOn.Count()].Add($Change)
        }
    }
    end {
        try {
            $commandHelper.Total = $commandHelper.Processed + ($PendingChanges.Values | Measure-Object -Property Count -Sum).Sum
            foreach ($DependencyCount in $PendingChanges.Keys) {
                Write-Information "Processing changes with $($DependencyCount) dependencies"
                foreach ($Change in $PendingChanges[$DependencyCount]) {
                    $commandHelper.Update($true, ('{0} Change: {1}' -f $Change.UpdateType, $(if ($Change.UpdateType -eq [UpdateType]::Online) { $Change.ProcessInfo } else { $Change.Id })))
                    if ($null -ne $Change.CommandObject -and $Change.CommandObject.HasWarnings()) {
                        $commandHelper.WriteVerbose(('{0} has warnings, skipping further processing' -f $Change.Id))
                        if ($Change.UpdateType -eq [UpdateType]::Source) {
                            $Change.DependsOn.Clear()
                            $Change.CommandObject | ConvertFrom-Json | Write-Output
                        }
                        continue
                    }

                    $NoPending = $true
                    foreach ($d in $Change.DependsOn.GetEnumerator()) {
                        if ($ProcessedChanges.Contains($d)) {
                            continue
                        }
                        $NoPending = $false
                        break
                    }
                    if (!$NoPending) {
                        $commandHelper.WriteWarning(('Unexpected Dependency Exception! {0}: {1}' -f $Change.CommandObject.Id, $Change.DependsOn))
                        $Change.CommandObject.Warning.Add([WarningType]::GeneralFailure, "Unexpected Dependency Exception! $($Change.DependsOn)")
                        if ($Change.UpdateType -eq [UpdateType]::Source) {
                            $Change.CommandObject | ConvertFrom-Json | Write-Output
                        }
                        continue
                    }
                    if ($Change.UpdateType -eq [UpdateType]::Source) {
                        $commandHelper.WriteVerbose(('{0} is a source change with no needed changes' -f $Change.Id))
                        $Change.CommandObject | ConvertFrom-Json | Write-Output
                        continue
                    }
                    try {
                        if ($PSCmdlet.ShouldProcess($Change.ProcessInfo.ToString())) {
                            $null = Invoke-Command -ScriptBlock $Change.ProcessInfo -NoNewScope -ErrorAction Stop
                            [E911ModuleState]::ShouldClearLIS = $true
                        }
                        if (![string]::IsNullOrEmpty($ExecutionPlanPath)) {
                            if (!$ExecutionPlanFileCreated) {
                                $ExecutionPlanPath = New-ExecutionPlanFile -ExecutionPlanPath $ExecutionPlanPath
                                $ExecutionPlanFileCreated = $true
                            }
                            $Change.ProcessInfo.ToString() | Add-Content -Path $ExecutionPlanPath -WhatIf:$false
                        }
                        $ProcessedChanges.Add($Change.Id)
                        [E911ModuleState]::ShouldClear = $true
                    }
                    catch {
                        $Change.CommandObject.Warning.Add([WarningType]::OnlineChangeError, "Command: { $($Change.ProcessInfo) } ErrorMessage: $($_.Exception.Message)")
                        $commandHelper.WriteWarning(('Command: {0} ErrorMessage: {1}' -f $Change.ProcessInfo, $_.Exception.Message))
                        if (![string]::IsNullOrEmpty($ExecutionPlanPath)) {
                            if (!$ExecutionPlanFileCreated) {
                                $ExecutionPlanPath = New-ExecutionPlanFile -ExecutionPlanPath $ExecutionPlanPath
                                $ExecutionPlanFileCreated = $true
                            }
                            '# COMMAND FAILED! ERROR:' | Add-Content -Path $ExecutionPlanPath -WhatIf:$false
                            "# $($_.Exception.Message -replace "`n","`n# ")" | Add-Content -Path $ExecutionPlanPath -WhatIf:$false
                        }
                    }
                }
            }
            $commandHelper.WriteVerbose('Finished')
        }
        finally {
            if ($null -ne $commandHelper) {
                $commandHelper.Dispose()
            }
        }
    }
}
