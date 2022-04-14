function Get-CsE911OnlineConfiguration {
    [CmdletBinding()]
    param (
        [switch]
        $IncludeOrphanedConfiguration
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
        # initialize caches
        [E911ModuleState]::InitializeCaches($vsw)

        $FoundLocationHashes = [Collections.Generic.List[string]]::new()
        $FoundAddressHashes = [Collections.Generic.List[string]]::new()
    }

    process {
        $i = 0
        $Total = [E911ModuleState]::OnlineNetworkObjects.Count
        $shouldp = $true
        foreach ($nObj in [E911ModuleState]::OnlineNetworkObjects.Values) {
            if (!$shouldp -and ($vsw.Elapsed.TotalMilliseconds - $LastMilliseconds) -ge [E911ModuleState]::Interval) { $shouldp = $true }
            if ($i -eq 0 -or ($shouldp -and ($vsw.Elapsed.TotalMilliseconds - $LastMilliseconds) -ge [E911ModuleState]::Interval)) {
                if ($i -gt 0) { $shouldp = $false }
                $ProgressParams = @{
                    Activity = 'Generating Configuration'
                    Status   = 'From Network Objects: [{0:F3}s] ({1}{2})' -f $vsw.Elapsed.TotalSeconds, $i, $(if ($Total -gt 1) { "/$Total" })
                    Id       = $MyInvocation.PipelinePosition
                }
                if ($Total -gt 1) {
                    $ProgressParams['PercentComplete'] = [int](($i / $Total) * 100)
                }
                $LastMilliseconds = $vsw.Elapsed.TotalMilliseconds
                Write-Progress @ProgressParams
            }
            $i++
            if ($null -ne $nObj._location -and !$FoundLocationHashes.Contains($nObj._location.GetHash())) {
                [void]$FoundLocationHashes.Add($nObj._location.GetHash())
            }
            if ($null -ne $nObj._location -and $null -ne $nObj._location._address -and !$FoundAddressHashes.Contains($nObj._location._address.GetHash())) {
                [void]$FoundAddressHashes.Add($nObj._location._address.GetHash())
            }
            Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] Processing $($nObj.Type):$($nObj.Identifier)"
            if ($null -eq $nObj._location -or $null -eq $nObj._location._address) {
                Write-Warning "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] $($nObj.Type):$($nObj.Identifier) is orphaned!"
                # how should I write this out?
                continue
            }

            $Row = [E911DataRow]::new($nObj)
            $Row.ToString() | ConvertFrom-Json | Write-Output
        }
        $i = 0
        $Total = [E911ModuleState]::OnlineLocations.Count
        $shouldp = $true
        foreach ($location in [E911ModuleState]::OnlineLocations.Values) {
            if (!$shouldp -and ($vsw.Elapsed.TotalMilliseconds - $LastMilliseconds) -ge [E911ModuleState]::Interval) { $shouldp = $true }
            if ($i -eq 0 -or ($shouldp -and ($vsw.Elapsed.TotalMilliseconds - $LastMilliseconds) -ge [E911ModuleState]::Interval)) {
                if ($i -gt 0) { $shouldp = $false }
                $ProgressParams = @{
                    Activity = 'Generating Configuration'
                    Status   = 'From Locations: [{0:F3}s] ({1}{2})' -f $vsw.Elapsed.TotalSeconds, $i, $(if ($Total -gt 1) { "/$Total" })
                    Id       = $MyInvocation.PipelinePosition
                }
                if ($Total -gt 1) {
                    $ProgressParams['PercentComplete'] = [int](($i / $Total) * 100)
                }
                $LastMilliseconds = $vsw.Elapsed.TotalMilliseconds
                Write-Progress @ProgressParams
            }
            $i++
            if ($FoundLocationHashes.Contains($location.GetHash())) {
                continue
            }
            [void]$FoundLocationHashes.Add($location.GetHash())
            if ($null -eq $location._address -and !$IncludeOrphanedConfiguration) {
                Write-Warning "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] $($location.Location) is orphaned!"
                continue
            }
            if (!$FoundAddressHashes.Contains($location._address.GetHash())) {
                [void]$FoundAddressHashes.Add($location._address.GetHash())
            }
            if ([string]::IsNullOrEmpty($location.Location)) {
                # don't output the default location if there is nothing associated
                continue
            }
            $Row = [E911DataRow]::new($location)
            $Row.ToString() | ConvertFrom-Json | Write-Output
        }
        $i = 0
        $Total = [E911ModuleState]::OnlineAddresses.Count
        $shouldp = $true
        foreach ($address in [E911ModuleState]::OnlineAddresses.Values) {
            if (!$shouldp -and ($vsw.Elapsed.TotalMilliseconds - $LastMilliseconds) -ge [E911ModuleState]::Interval) { $shouldp = $true }
            if ($i -eq 0 -or ($shouldp -and ($vsw.Elapsed.TotalMilliseconds - $LastMilliseconds) -ge [E911ModuleState]::Interval)) {
                if ($i -gt 0) { $shouldp = $false }
                $ProgressParams = @{
                    Activity = 'Generating Configuration'
                    Status   = 'From Addresses: [{0:F3}s] ({1}{2})' -f $vsw.Elapsed.TotalSeconds, $i, $(if ($Total -gt 1) { "/$Total" })
                    Id       = $MyInvocation.PipelinePosition
                }
                if ($Total -gt 1) {
                    $ProgressParams['PercentComplete'] = [int](($i / $Total) * 100)
                }
                $LastMilliseconds = $vsw.Elapsed.TotalMilliseconds
                Write-Progress @ProgressParams
            }
            $i++
            if ($FoundAddressHashes.Contains($address.GetHash())) {
                continue
            }
            [void]$FoundAddressHashes.Add($address.GetHash())
            $Row = [E911DataRow]::new($address)
            $Row.ToString() | ConvertFrom-Json | Write-Output
        }
        Write-Progress -Activity 'Generating Configuration' -Id $MyInvocation.PipelinePosition -Completed
    }
    end {
        $vsw.Stop()
        Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] Finished"
    }
}
