function Get-CsE911NeededChange {
    [CmdletBinding()]
    [OutputType([ChangeObject])]
    param (
        # Parameter help description
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSCustomObject[]]
        $LocationConfiguration,

        [switch]
        $ForceOnlineCheck
    )

    begin {
        $vsw = [Diagnostics.Stopwatch]::StartNew()
        $StartingCount = [Math]::Max(0, [E911ModuleState]::MapsQueryCount)
        Write-Verbose "[$($vsw.Elapsed.TotalSeconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] Beginning..."
        Assert-TeamsIsConnected
        [E911ModuleState]::ForceOnlineCheck = $ForceOnlineCheck
        [E911ModuleState]::ShouldClear = $true
        [E911ModuleState]::InitializeCaches($vsw)
        $Rows = [Collections.Generic.List[E911DataRow]]::new()
        Write-Verbose "[$($vsw.Elapsed.TotalSeconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] Validating Rows..."
        $i = 0
        $shouldp = $true
        $LastMilliseconds = $vsw.Elapsed.TotalMilliseconds
    }
    process {
        foreach ($obj in $LocationConfiguration) {
            $lc = [E911DataRow]::new($obj)
            if ($MyInvocation.PipelinePosition -gt 1) {
                $Total = $Input.Count
            }
            else {
                $Total = $LocationConfiguration.Count
            }
            if (!$shouldp -and ($vsw.Elapsed.TotalMilliseconds - $LastMilliseconds) -ge [E911ModuleState]::Interval) { $shouldp = $true }
            if ($i -eq 0 -or ($shouldp -and ($vsw.Elapsed.TotalMilliseconds - $LastMilliseconds) -ge [E911ModuleState]::Interval)) {
                if ($i -gt 0) { $shouldp = $false }
                $ProgressParams = @{
                    Activity = 'Validating Rows'
                    Status   = '[{0:F3}s] ({1}{2}) {3}' -f $vsw.Elapsed.TotalSeconds, $i, $(if ($Total -gt 1) { "/$Total" }), $lc.RowName()
                    Id       = $MyInvocation.PipelinePosition
                }
                if ($Total -gt 1) {
                    $ProgressParams['PercentComplete'] = [int](($i / $Total) * 100)
                }
                $LastMilliseconds = $vsw.Elapsed.TotalMilliseconds
                Write-Progress @ProgressParams
            }
            $i++
            Write-Verbose "[$($vsw.Elapsed.TotalSeconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] [Row $i] $($lc.RowName()) Validating object..."
            if (!$lc.HasChanged()) {
                # no changes to this row since last processing, skip
                if (!$ForceOnlineCheck) {
                    Write-Verbose "[$($vsw.Elapsed.TotalSeconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] [Row $i] $($lc.RowName()) has not changed - skipping..."
                    [ChangeObject]::new($lc) | Write-Output
                    continue
                }
                Write-Verbose "[$($vsw.Elapsed.TotalSeconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] [Row $i] $($lc.RowName()) has not changed but ForceOnlineCheck is set..."
            }
            if ($lc.HasWarnings()) {
                Write-Verbose "[$($vsw.Elapsed.TotalSeconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] [Row $i] $($lc.RowName()): validation failed with $($lc.Warning.Count()) issue$(if($lc.Warning.Count() -gt 1) {'s'})!"
                [ChangeObject]::new($lc) | Write-Output
                continue
            }
            [void]$Rows.Add($lc)
        }
    }

    end {
        Write-Progress -Activity 'Validating Rows' -Completed -Id $MyInvocation.PipelinePosition
        Write-Verbose "[$($vsw.Elapsed.TotalSeconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] Processing Rows..."
        $i = 0
        $shouldp = $true
        $LastMilliseconds = $vsw.Elapsed.TotalMilliseconds
        $Total = $Rows.Count
        while ($i -lt $Rows.Count) {
            $Row = $Rows[$i]
            if (!$shouldp -and ($vsw.Elapsed.TotalMilliseconds - $LastMilliseconds) -ge [E911ModuleState]::Interval) { $shouldp = $true }
            if ($i -eq 0 -or ($shouldp -and ($vsw.Elapsed.TotalMilliseconds - $LastMilliseconds) -ge [E911ModuleState]::Interval)) {
                if ($i -gt 0) { $shouldp = $false }
                $ProgressParams = @{
                    Activity = 'Generating Change Commands'
                    Status   = '[{0:F3}s] ({1}{2}) {3}' -f $vsw.Elapsed.TotalSeconds, $i, $(if ($Total -gt 1) { "/$Total" }), $Row.RowName()
                    Id       = $MyInvocation.PipelinePosition
                }
                if ($Total -gt 1) {
                    $ProgressParams['PercentComplete'] = [int](($i / $Total) * 100)
                }
                $LastMilliseconds = $vsw.Elapsed.TotalMilliseconds
                Write-Progress @ProgressParams
            }
            $i++
            if ($Row.HasWarnings()) {
                Write-Verbose "[$($vsw.Elapsed.TotalSeconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] [Row $i] $($Row.RowName()): validation failed with $($Row.Warning.Count()) issue$(if($Row.Warning.Count() -gt 1) {'s'})!"
                [ChangeObject]::new($Row) | Write-Output
                continue
            }
            $Commands = $Row.GetChangeCommands($vsw)
            foreach ($Command in $Commands) {
                if ($Command.UpdateType -eq [UpdateType]::Online) {
                    $Command.CommandObject._commandGenerated = $true
                }
                $Command | Write-Output
            }
        }
        $vsw.Stop()
        Write-Verbose "[$($vsw.Elapsed.TotalSeconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] Performed $([E911ModuleState]::MapsQueryCount - $StartingCount) Maps Queries"
        Write-Verbose "[$($vsw.Elapsed.TotalSeconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] Finished"
        Write-Progress -Activity 'Generating Change Commands' -Completed -Id $MyInvocation.PipelinePosition
    }
}

