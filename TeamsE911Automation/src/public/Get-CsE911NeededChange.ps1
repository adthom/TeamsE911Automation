function Get-CsE911NeededChange {
    [CmdletBinding()]
    [OutputType([ChangeObject])]
    param (
        # Parameter help description
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [E911DataRow[]]
        $LocationConfiguration,

        [switch]
        $ForceOnlineCheck
    )

    begin {
        $vsw = [Diagnostics.Stopwatch]::StartNew()
        $StartingCount = [E911ModuleState]::MapsQueryCount
        Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] Beginning..."
        try {
            [Microsoft.TeamsCmdlets.Powershell.Connect.TeamsPowerShellSession]::ClientAuthenticated()
            # maybe check for token expiration here?
        }
        catch {
            throw "Run Connect-MicrosoftTeams prior to executing this script!"
        }
        [E911ModuleState]::ForceOnlineCheck = $ForceOnlineCheck
        # initialize caches
        [E911ModuleState]::InitializeCaches($vsw)
        $Rows = [Collections.Generic.List[E911DataRow]]::new()
        Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] Validating Rows..."
        $i = 0
        $prevI = $i
        $shouldp = $true
        $interval = 2
        $LastSeconds = $vsw.Elapsed.TotalSeconds
    }
    process {
        foreach ($lc in $LocationConfiguration) {
            if ($MyInvocation.PipelinePosition -gt 1) {
                $Total = $Input.Count
            }
            else {
                $Total = $LocationConfiguration.Count
            }
            if (($vsw.Elapsed.TotalSeconds - $LastSeconds) -gt ($interval + 1)) { $shouldp = $true }
            if ($i -eq 0 -or ($shouldp -and ($vsw.Elapsed.TotalSeconds - $LastSeconds) -gt $interval)) {
                if ($i -gt 0) { $shouldp = $false }
                $ProgressParams = @{
                    Activity         = 'Validating Rows'
                    CurrentOperation = '[{0:F3}s] ({1}{2}) {3}' -f $vsw.Elapsed.TotalSeconds, $i, $(if ($Total -gt 1) { "/$Total" }), $lc.RowName()
                    Id               = $MyInvocation.PipelinePosition
                }
                if ($i -gt 0 -and $Total -gt 1) {
                    $LastSegment = $vsw.Elapsed.TotalSeconds - $LastSeconds
                    $Remaining = [int]((($Total - $i) / ($i - $prevI)) * $LastSegment)
                    $ProgressParams['PercentComplete'] = ($i / $Total * 100)
                    $ProgressParams['SecondsRemaining'] = $Remaining
                }
                $LastSeconds = $vsw.Elapsed.TotalSeconds
                $prevI = $i
                Write-Progress @ProgressParams
            }
            $i++
            Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] [Row $i] $($lc.RowName()) Validating object..."
            if (!$lc.HasChanged()) {
                # no changes to this row since last processing, skip
                if (!$ForceOnlineCheck) {
                    Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] [Row $i] $($lc.RowName()) has not changed - skipping..."
                    [ChangeObject]::new($lc) | Write-Output
                    continue
                }
                Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] [Row $i] $($lc.RowName()) has not changed but ForceOnlineCheck is set..."
            }
            if ($lc.HasWarnings()) {
                Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] [Row $i] $($lc.RowName()): validation failed with $($lc.Warning.Count()) issue$(if($lc.Warning.Count() -gt 1) {'s'})!"
                [ChangeObject]::new($lc) | Write-Output
                continue
            }
            [void]$Rows.Add($lc)
        }
    }

    end {
        Write-Progress -Activity 'Validating Rows' -Completed -Id $MyInvocation.PipelinePosition
        Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] Processing Rows..."
        $i = 0
        $prevI = $i
        $shouldp = $true
        $interval = 15
        $LastSeconds = $vsw.Elapsed.TotalSeconds
        $Total = $Rows.Count
        $AddressChanges = [Collections.Generic.List[ItemId]]::new()
        $GetAddressChanges = [Collections.Generic.List[ItemId]]::new()
        $LocationChanges = [Collections.Generic.List[ItemId]]::new()
        foreach ($Row in $Rows) {
            if (($vsw.Elapsed.TotalSeconds - $LastSeconds) -gt ($interval + 1)) { $shouldp = $true }
            if ($i -eq 0 -or ($shouldp -and ($vsw.Elapsed.TotalSeconds - $LastSeconds) -gt $interval)) {
                if ($i -gt 0) { $shouldp = $false }
                $ProgressParams = @{
                    Activity         = 'Generating Change Commands'
                    CurrentOperation = '[{0:F3}s] ({1}{2}) {3}' -f $vsw.Elapsed.TotalSeconds, $i, $(if ($Total -gt 1) { "/$Total" }), $lc.RowName()
                    Id               = $MyInvocation.PipelinePosition
                }
                if ($i -gt 0 -and $Total -gt 1) {
                    $LastSegment = $vsw.Elapsed.TotalSeconds - $LastSeconds
                    $Remaining = [int]((($Total - $i) / ($i - $prevI)) * $LastSegment)
                    $ProgressParams['PercentComplete'] = ($i / $Total * 100)
                    $ProgressParams['SecondsRemaining'] = $Remaining
                }
                $LastSeconds = $vsw.Elapsed.TotalSeconds
                $prevI = $i
                Write-Progress @ProgressParams
            }
            $i++
            if ($Row.HasWarnings()) {
                Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] [Row $i] $($Row.RowName()): validation failed with $($Row.Warning.Count()) issue$(if($Row.Warning.Count() -gt 1) {'s'})!"
                [ChangeObject]::new($Row) | Write-Output
                continue
            }
            $Commands = $Row.GetChangeCommands($vsw)
            foreach ($Command in $Commands) {
                if ($Command.CommandType -eq [CommandType]::Address) {
                    if ($GetAddressChanges.Contains($Command.Id)) {
                        throw # this should not be possible
                    }
                    if ($AddressChanges.Contains($Command.Id) ) {
                        Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] $($Row.RowName()): Address change command already exists, skipping..."
                        continue
                    }
                    [void]$AddressChanges.Add($Command.Id)
                }
                if ($Command.CommandType -eq [CommandType]::GetAddress) {
                    if ($AddressChanges.Contains($Command.Id)) {
                        throw # this should not be possible
                    }
                    if ($GetAddressChanges.Contains($Command.Id) ) {
                        Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] $($Row.RowName()): Get address command already exists, skipping..."
                        continue
                    }
                    [void]$GetAddressChanges.Add($Command.Id)
                }
                if ($Command.CommandType -eq [CommandType]::Location) {
                    if ($LocationChanges.Contains($Command.Id)) {
                        Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] $($Row.RowName()): Location change command already exists, skipping..."
                        continue
                    }
                    [void]$LocationChanges.Add($Command.Id)
                }
                $Command | Write-Output
            }
        }
        $vsw.Stop()
        Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] Performed $([E911ModuleState]::MapsQueryCount - $StartingCount) Maps Queries"
        Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] Finished"
        Write-Progress -Activity 'Generating Change Commands' -Completed -Id $MyInvocation.PipelinePosition
    }
}

