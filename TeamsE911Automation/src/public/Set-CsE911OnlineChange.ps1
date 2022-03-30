function Set-CsE911OnlineChange {
    [CmdletBinding(DefaultParameterSetName = 'Execute')]
    param (
        # Parameter help description
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'Execute')]
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'Validate')]
        [ChangeObject[]]
        $PendingChange,

        [Parameter(Mandatory = $true, ParameterSetName = 'Validate')]
        [switch]
        $ValidateOnly,

        [Parameter(Mandatory = $false, ParameterSetName = 'Validate')]
        [string]
        $ExecutionPlanPath
    )
    begin {
        $vsw = [Diagnostics.Stopwatch]::StartNew()
        Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] Beginning..."
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
                $FileName = 'E911ExecutionPlan_{0:yyyyMMdd_HHmmss}.txt' -f [DateTime]::Now
                $ExecutionPlanPath = Join-Path -Path $ExecutionPlanPath -ChildPath $FileName
            }
            try {
                Set-Content -Path $ExecutionPlanPath -ErrorAction Stop -Value '# *******************************************************************************'
                Add-Content -Path $ExecutionPlanPath -ErrorAction Stop -Value '# Teams E911 Automation generated execution plan'
                Add-Content -Path $ExecutionPlanPath -ErrorAction Stop -Value '# The following commands are what the workflow would execute in a live scenario'
                Add-Content -Path $ExecutionPlanPath -ErrorAction Stop -Value '# These must be executed from a valid MicrosoftTeams PowerShell session'
                Add-Content -Path $ExecutionPlanPath -ErrorAction Stop -Value '# These commands must be executed in-order in the same PowerShell session'
                Add-Content -Path $ExecutionPlanPath -ErrorAction Stop -Value '# *******************************************************************************'
                Add-Content -Path $ExecutionPlanPath -ErrorAction Stop -Value ''
            }
            catch {
                $ExecutionPlanPath = ''
            }
            if ([string]::IsNullOrEmpty($ExecutionPlanPath)) {
                Write-Warning "$($ExecutionPlanPath) is not a writeable path, execution plan will not be saved!"
            }
        }
        $PendingChanges = [Collections.Generic.Dictionary[int, Collections.Generic.List[ChangeObject]]]::new()
        $i = 0
        $prevI = $i
        $shouldp = $true
        $changeCount = 0
        $LastSeconds = $vsw.Elapsed.TotalSeconds
        $interval = 5
    }
    process {
        foreach ($Change in $PendingChange) {
            if ($MyInvocation.PipelinePosition -gt 1) {
                $Total = $Input.Count
            }
            else {
                $Total = $PendingChange.Count
            }
            if (($vsw.Elapsed.TotalSeconds - $LastSeconds) -gt ($interval + 1)) { $shouldp = $true }
            if ($i -eq 0 -or ($shouldp -and ($vsw.Elapsed.TotalSeconds - $LastSeconds) -gt $interval)) {
                if ($i -gt 0) { $shouldp = $false }
                $ProgressParams = @{
                    Activity         = 'Processing changes'
                    CurrentOperation = '[{0:F3}s] ({1}{2}) {3} Change: {4}' -f $vsw.Elapsed.TotalSeconds, $i, $(if ($Total -gt 1) { "/$Total" }), $Change.UpdateType, $Change.Id
                    Id               = $MyInvocation.PipelinePosition
                }
                if ($i -gt 0 -and $Total -gt 1) {
                    $LastSegment = $vsw.Elapsed.TotalSeconds - $LastSeconds
                    $Remaining = [int]((($Total - $i) / ($i - $prevI)) * $LastSegment)
                    $ProgressParams['PercentComplete'] = ($i / $Total) * 100
                    $ProgressParams['SecondsRemaining'] = $Remaining
                }
                $LastSeconds = $vsw.Elapsed.TotalSeconds
                $prevI = $i
                Write-Progress @ProgressParams
            }
            $i++
            if ($null -ne $Change.CommandObject -and $Change.CommandObject.HasWarnings()) {
                Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] $($Change.Id) has warnings, skipping further processing"
                if ($Change.UpdateType -eq [UpdateType]::Source) {
                    $Change.DependsOn.Clear()
                    $Change.CommandObject | ConvertFrom-Json | Write-Output
                }
                continue
            }
            if ($Change.DependsOn.Count() -eq 0) {
                if ($Change.UpdateType -eq [UpdateType]::Source) {
                    Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] $($Change.Id) is a source change with no needed changes"
                    $Change.CommandObject | ConvertFrom-Json | Write-Output
                    continue
                }
                $changeCount++
                try {
                    Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] $($Change.ProcessInfo)"
                    if (!$ValidateOnly) {
                        Invoke-Command -ScriptBlock $Change.ProcessInfo -NoNewScope -ErrorAction Stop | Out-Null
                    }
                    if ($ValidateOnly -and $null -ne $ExecutionPlanPath) {
                        $Change.ProcessInfo.ToString() | Add-Content -Path $ExecutionPlanPath
                    }
                    [E911ModuleState]::ShouldClear = $true
                }
                catch {
                    $Change.CommandObject.Warning.Add([WarningType]::OnlineChangeError, "Command: { $($Change.ProcessInfo) } ErrorMessage: $($_.Exception.Message)")
                    Write-Warning "Command: { $($Change.ProcessInfo) } ErrorMessage: $($_.Exception.Message)"
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
        if ($PendingChanges.Keys.Count -eq 0) {
            $vsw.Stop()
            Write-Progress -Activity 'Processing changes' -Completed -Id $MyInvocation.PipelinePosition
            Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] Finished"
            return
        }
        $shouldp = $true
        $LastSeconds = $vsw.Elapsed.TotalSeconds
        $prevI = $i
        $Total = $PendingChange.Count # $i + $PendingChanges.Values.ForEach({$_.Where({$_.UpdateType -eq [UpdateType]::Online})}).Count
        foreach ($DependencyCount in $PendingChanges.Keys) {
            foreach ($Change in $PendingChanges[$DependencyCount]) {
                if (($vsw.Elapsed.TotalSeconds - $LastSeconds) -gt ($interval + 1)) { $shouldp = $true }
                if ($shouldp -and ($vsw.Elapsed.TotalSeconds - $LastSeconds) -gt $interval) {
                    $shouldp = $false
                    $ProgressParams = @{
                        Activity         = "Processing changes"
                        CurrentOperation = '[{0:F3}s] ({1}{2}) {3} Change: {4}' -f $vsw.Elapsed.TotalSeconds, $i, $(if ($Total -gt 1) { "/$Total" }), $Change.UpdateType, $Change.Id
                        Id               = $MyInvocation.PipelinePosition
                    }
                    if ($i -gt 0 -and $Total -gt 1) {
                        $SecondsPer = $i / $LastSeconds
                        # $LastSegment = $vsw.Elapsed.TotalSeconds - $LastSeconds
                        $Remaining = ($Total - $i) * $SecondsPer
                        $ProgressParams['PercentComplete'] = ($i / $Total) * 100
                        $ProgressParams['SecondsRemaining'] = $Remaining
                    }
                    $LastSeconds = $vsw.Elapsed.TotalSeconds
                    $prevI = $i
                    Write-Progress @ProgressParams
                }
                $i++
                if ($null -ne $Change.CommandObject -and $Change.CommandObject.HasWarnings()) {
                    Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] $($Change.Id) has warnings, skipping further processing"
                    if ($Change.UpdateType -eq [UpdateType]::Source) {
                        $Change.DependsOn.Clear()
                        $Change.CommandObject | ConvertFrom-Json | Write-Output
                    }
                    continue
                }
                if ($Change.UpdateType -eq [UpdateType]::Source) {
                    Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] $($Change.Id) is a source change with no needed changes"
                    $Change.CommandObject | ConvertFrom-Json | Write-Output
                    continue
                }
                $changeCount++
                try {
                    Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] $($Change.ProcessInfo)"
                    if (!$ValidateOnly) {
                        Invoke-Command -ScriptBlock $Change.ProcessInfo -NoNewScope -ErrorAction Stop | Out-Null
                    }
                    if ($ValidateOnly -and $null -ne $ExecutionPlanPath) {
                        $Change.ProcessInfo.ToString() | Add-Content -Path $ExecutionPlanPath
                    }
                    [E911ModuleState]::ShouldClear = $true
                }
                catch {
                    $Change.CommandObject.Warning.Add([WarningType]::OnlineChangeError, "Command: { $($Change.ProcessInfo) } ErrorMessage: $($_.Exception.Message)")
                    Write-Warning "Command: { $($Change.ProcessInfo) } ErrorMessage: $($_.Exception.Message)"
                }
            }
        }
        $vsw.Stop()
        Write-Progress -Activity 'Processing changes' -Completed -Id $MyInvocation.PipelinePosition
        Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] Finished"
    }
}

