function Set-CsE911OnlineChange {
    [CmdletBinding(DefaultParameterSetName = 'Execute', SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        # Parameter help description
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'Execute')]
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'Validate')]
        [ChangeObject[]]
        $PendingChange,

        [Parameter(Mandatory = $true, ParameterSetName = 'Validate')]
        [switch]
        $ValidateOnly,

        [Parameter(Mandatory = $false)]
        [string]
        $ExecutionPlanPath
    )
    begin {
        $vsw = [Diagnostics.Stopwatch]::StartNew()
        Write-Verbose "[$($vsw.Elapsed.TotalSeconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] Beginning..."
        try {
            [Microsoft.TeamsCmdlets.Powershell.Connect.TeamsPowerShellSession]::ClientAuthenticated()
            # maybe check for token expiration here?
        }
        catch {
            throw "Run Connect-MicrosoftTeams prior to executing this script!"
        }
        if (![string]::IsNullOrEmpty($ExecutionPlanPath)) {
            # validate path is valid here, add header to file
            if (!(Test-Path -Path $ExecutionPlanPath -IsValid)) {
                $ExecutionPlanPath = ''
            }
            if ((Test-Path -Path $ExecutionPlanPath -PathType Container -ErrorAction SilentlyContinue)) {
                # get new file name:
                $ExecutionName = if ($ValidateOnly) { 'ExecutionPlan' } else { 'ExecutedCommands' }
                $Date = '{0:yyyy-MM-dd HH:mm:ss}' -f [DateTime]::Now
                $FileName = 'E911{0}_{1:yyyyMMdd_HHmmss}.txt' -f $ExecutionName, [DateTime]::Now
                $ExecutionPlanPath = Join-Path -Path $ExecutionPlanPath -ChildPath $FileName
            }
            try {
                Set-Content -Path $ExecutionPlanPath -ErrorAction Stop -Value '# *******************************************************************************'
                if ($ValidateOnly) {
                    Add-Content -Path $ExecutionPlanPath -ErrorAction Stop -Value '# Teams E911 Automation generated execution plan'
                    Add-Content -Path $ExecutionPlanPath -ErrorAction Stop -Value '# The following commands are what the workflow would execute in a live scenario'
                    Add-Content -Path $ExecutionPlanPath -ErrorAction Stop -Value '# These must be executed from a valid MicrosoftTeams PowerShell session'
                    Add-Content -Path $ExecutionPlanPath -ErrorAction Stop -Value '# These commands must be executed in-order in the same PowerShell session'
                }
                else {
                    Add-Content -Path $ExecutionPlanPath -ErrorAction Stop -Value '# Teams E911 Automation executed commands'
                    Add-Content -Path $ExecutionPlanPath -ErrorAction Stop -Value "# The following commands are what workflow executed at $Date"
                }
                Add-Content -Path $ExecutionPlanPath -ErrorAction Stop -Value '# *******************************************************************************'
                Add-Content -Path $ExecutionPlanPath -ErrorAction Stop -Value ''
            }
            catch {
                Write-Warning "file write failed: $($_.Exception.Message)"
                $ExecutionPlanPath = ''
            }
            if ([string]::IsNullOrEmpty($ExecutionPlanPath)) {
                Write-Warning "$($ExecutionPlanPath) is not a writeable path, execution plan will not be saved!"
            }
        }
        $ProcessedChanges = [Collections.Generic.List[ItemId]]::new()
        $PendingChanges = [Collections.Generic.Dictionary[int, Collections.Generic.List[ChangeObject]]]::new()
        $i = 0
        $shouldp = $true
        $changeCount = 0
        $LastMilliseconds = $vsw.Elapsed.TotalMilliseconds
        Write-Information "Processing changes with 0 dependencies"
    }
    process {
        foreach ($Change in $PendingChange) {
            if ($MyInvocation.PipelinePosition -gt 1) {
                $Total = $Input.Count
            }
            else {
                $Total = $PendingChange.Count
            }
            if (!$shouldp -and ($vsw.Elapsed.TotalMilliseconds - $LastMilliseconds) -ge [E911ModuleState]::Interval) { $shouldp = $true }
            if ($i -eq 0 -or ($shouldp -and ($vsw.Elapsed.TotalMilliseconds - $LastMilliseconds) -ge [E911ModuleState]::Interval)) {
                $shouldp = $false
                $ProgressParams = @{
                    Activity = 'Processing changes'
                    Status   = '[{0:F3}s] ({1}{2}) {3} Change: {4}' -f $vsw.Elapsed.TotalSeconds, $i, $(if ($Total -gt 1) { "/$Total" }), $Change.UpdateType, $(if ($Change.UpdateType -eq [UpdateType]::Online) { $Change.ProcessInfo } else { $Change.Id })
                    Id       = $MyInvocation.PipelinePosition
                }
                if ($Total -gt 1) {
                    $ProgressParams['PercentComplete'] = [int](($i / $Total) * 100)
                }
                $LastMilliseconds = $vsw.Elapsed.TotalMilliseconds
                Write-Progress @ProgressParams
            }
            $i++
            if ($null -ne $Change.CommandObject -and $Change.CommandObject.HasWarnings()) {
                Write-Verbose "[$($vsw.Elapsed.TotalSeconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] $($Change.Id) has warnings, skipping further processing"
                if ($Change.UpdateType -eq [UpdateType]::Source) {
                    $Change.DependsOn.Clear()
                    $Change.CommandObject | ConvertFrom-Json | Write-Output
                }
                continue
            }
            if ($Change.DependsOn.Count() -eq 0) {
                if ($Change.UpdateType -eq [UpdateType]::Source) {
                    Write-Verbose "[$($vsw.Elapsed.TotalSeconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] $($Change.Id) is a source change with no needed changes"
                    $Change.CommandObject | ConvertFrom-Json | Write-Output
                    continue
                }
                $changeCount++
                try {
                    Write-Verbose "[$($vsw.Elapsed.TotalSeconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] $($Change.ProcessInfo)"
                    if (!$ValidateOnly) {
                        if ($PSCmdlet.ShouldProcess()) {
                            $null = Invoke-Command -ScriptBlock $Change.ProcessInfo -NoNewScope -ErrorAction Stop
                        }
                    }
                    if (![string]::IsNullOrEmpty($ExecutionPlanPath)) {
                        $Change.ProcessInfo.ToString() | Add-Content -Path $ExecutionPlanPath
                    }
                    $ProcessedChanges.Add($Change.Id)
                    [E911ModuleState]::ShouldClear = $true
                }
                catch {
                    $Change.CommandObject.Warning.Add([WarningType]::OnlineChangeError, "Command: { $($Change.ProcessInfo) } ErrorMessage: $($_.Exception.Message)")
                    Write-Warning "Command: { $($Change.ProcessInfo) } ErrorMessage: $($_.Exception.Message)"
                    if (![string]::IsNullOrEmpty($ExecutionPlanPath)) {
                        "# COMMAND FAILED! ERROR:" | Add-Content -Path $ExecutionPlanPath
                        "# $($_.Exception.Message -replace "`n","`n# ")" | Add-Content -Path $ExecutionPlanPath
                    }
                }
                continue
            }
            if (!$PendingChanges.ContainsKey($Change.DependsOn.Count())) {
                $PendingChanges[$Change.DependsOn.Count()] = [Collections.Generic.List[ChangeObject]]::new()
            }
            [void]$PendingChanges[$Change.DependsOn.Count()].Add($Change)
        }
    }
    end {
        $shouldp = $true
        $LastMilliseconds = $vsw.Elapsed.TotalMilliseconds
        $Total = $PendingChange.Count
        foreach ($DependencyCount in $PendingChanges.Keys) {
            Write-Information "Processing changes with $($DependencyCount) dependencies"
            foreach ($Change in $PendingChanges[$DependencyCount]) {
                if (!$shouldp -and ($vsw.Elapsed.TotalMilliseconds - $LastMilliseconds) -ge [E911ModuleState]::Interval) { $shouldp = $true }
                if ($i -eq 0 -or ($shouldp -and ($vsw.Elapsed.TotalMilliseconds - $LastMilliseconds) -ge [E911ModuleState]::Interval)) {
                    $shouldp = $false
                    $ProgressParams = @{
                        Activity = 'Processing changes'
                        Status   = '[{0:F3}s] ({1}{2}) {3} Change: {4}' -f $vsw.Elapsed.TotalSeconds, $i, $(if ($Total -gt 1) { "/$Total" }), $Change.UpdateType, $(if ($Change.UpdateType -eq [UpdateType]::Online) { $Change.ProcessInfo } else { $Change.Id })
                        Id       = $MyInvocation.PipelinePosition
                    }
                    if ($Total -gt 1) {
                        $ProgressParams['PercentComplete'] = [int](($i / $Total) * 100)
                    }
                    $LastMilliseconds = $vsw.Elapsed.TotalMilliseconds
                    Write-Progress @ProgressParams
                }
                $i++
                if ($null -ne $Change.CommandObject -and $Change.CommandObject.HasWarnings()) {
                    Write-Verbose "[$($vsw.Elapsed.TotalSeconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] $($Change.Id) has warnings, skipping further processing"
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
                    Write-Warning "Unexpected Dependency Exception! $($Change.CommandObject.Id.ToString()): $($Change.DependsOn.ToString())"
                    $Change.CommandObject.Warning.Add([WarningType]::GeneralFailure, "Unexpected Dependency Exception! $($Change.DependsOn.ToString())")
                    if ($Change.UpdateType -eq [UpdateType]::Source) {
                        $Change.CommandObject | ConvertFrom-Json | Write-Output
                    }
                    continue
                }
                if ($Change.UpdateType -eq [UpdateType]::Source) {
                    Write-Verbose "[$($vsw.Elapsed.TotalSeconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] $($Change.Id) is a source change with no needed changes"
                    $Change.CommandObject | ConvertFrom-Json | Write-Output
                    continue
                }
                $changeCount++
                try {
                    Write-Verbose "[$($vsw.Elapsed.TotalSeconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] $($Change.ProcessInfo)"
                    if (!$ValidateOnly) {
                        if ($PSCmdlet.ShouldProcess()) {
                            $null = Invoke-Command -ScriptBlock $Change.ProcessInfo -NoNewScope -ErrorAction Stop
                        }
                    }
                    if (![string]::IsNullOrEmpty($ExecutionPlanPath)) {
                        $Change.ProcessInfo.ToString() | Add-Content -Path $ExecutionPlanPath
                    }
                    $ProcessedChanges.Add($Change.Id)
                    [E911ModuleState]::ShouldClear = $true
                }
                catch {
                    $Change.CommandObject.Warning.Add([WarningType]::OnlineChangeError, "Command: { $($Change.ProcessInfo) } ErrorMessage: $($_.Exception.Message)")
                    Write-Warning "Command: { $($Change.ProcessInfo) } ErrorMessage: $($_.Exception.Message)"
                    if (![string]::IsNullOrEmpty($ExecutionPlanPath)) {
                        "# COMMAND FAILED! ERROR:" | Add-Content -Path $ExecutionPlanPath
                        "# $($_.Exception.Message -replace "`n","`n# ")" | Add-Content -Path $ExecutionPlanPath
                    }
                }
            }
        }
        $vsw.Stop()
        Write-Progress -Activity 'Processing changes' -Completed -Id $MyInvocation.PipelinePosition
        Write-Verbose "[$($vsw.Elapsed.TotalSeconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] Finished"
    }
}

