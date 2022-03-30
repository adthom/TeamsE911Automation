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
        [E911ModuleState]::ForceOnlineCheck = $ForceOnlineCheck
        # initialize caches
        [E911ModuleState]::InitializeCaches($vsw)

        $FoundLocationHashes = [Collections.Generic.List[string]]::new()
        $FoundAddressHashes = [Collections.Generic.List[string]]::new()
    }

    process {
        foreach ($nObj in [E911ModuleState]::OnlineNetworkObjects.Values) {
            Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] Processing $($nObj.Type):$($nObj.Identifier)"
            if ($null -eq $nObj._location -or $null -eq $nObj._location._address) {
                Write-Warning "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] $($nObj.Type):$($nObj.Identifier) is orphaned!"
                # how should I write this out?
                continue
            }
            if ($null -ne $nObj._location -and !$FoundLocationHashes.Contains($nObj._location.GetHash())) {
                [void]$FoundLocationHashes.Add($nObj._location.GetHash())
            }
            if ($null -ne $nObj._location -and $null -ne $nObj._location._location -and !$FoundAddressHashes.Contains($nObj._location._address.GetHash())) {
                [void]$FoundAddressHashes.Add($nObj._location._address.GetHash())
            }
            $Row = [E911DataRow]::new($nObj)
            $Row.ToString() | ConvertFrom-Json | Write-Output
        }
        if ($IncludeOrphanedConfiguration) {
            foreach ($location in [E911ModuleState]::OnlineLocations.Values) {
                if ($location.GetHash() -in $FoundLocationHashes) {
                    continue
                }
                if ($null -eq $location._address -and !$IncludeOrphanedConfiguration) {
                    Write-Warning "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] $($location.Location) is orphaned!"
                    continue
                }
                # how should I handle these locations?
            }
            foreach ($address in [E911ModuleState]::OnlineAddresses.Values) {
                if ($address.GetHash() -in $FoundAddressHashes) {
                    continue
                }
                # how should I handle these addresses?
            }
        }
    }

    end {
        $vsw.Stop()
        Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] Finished"
    }
}

