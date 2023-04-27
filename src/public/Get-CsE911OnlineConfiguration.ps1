using module '..\..\modules\PSClassExtensions\bin\release\PSClassExtensions\PSClassExtensions.psd1'
using namespace System.Collections.Generic

function Get-CsE911OnlineConfiguration {
    [CmdletBinding()]
    param (
        [switch]
        $IncludeOrphanedConfiguration
    )
    end {
        Assert-TeamsIsConnected
        $commandHelper = [PSFunctionHost]::StartNew($PSCmdlet, 'Getting Existing Configuration', [E911ModuleState]::Interval)
        try {
            [E911ModuleState]::InitializeCaches($commandHelper)
            $FoundLocationHashes = [HashSet[string]]@()
            $FoundAddressHashes = [HashSet[string]]@()
            $generatorHelper = [PSFunctionHost]::StartNew($commandHelper, 'Generating Configuration')
            $generatorHelper.Total = [E911ModuleState]::OnlineNetworkObjects.Count
            foreach ($nObj in [E911ModuleState]::OnlineNetworkObjects.Values) {
                $generatorHelper.Update($true, 'From Network Objects')
                if ($null -ne $nObj._location) {
                    [void]$FoundLocationHashes.Add($nObj._location.GetHash())
                    if ($null -ne $nObj._location._address) {
                        [void]$FoundAddressHashes.Add($nObj._location._address.GetHash())
                    }
                }
                $generatorHelper.WriteVerbose(('Processing {0}:{1}' -f $nObj.Type, $nObj.Identifier))
                if ($null -eq $nObj._location -or $null -eq $nObj._location._address -or ($nObj._isOnline -and !($nObj._location._isOnline -and $nObj._location._address._isOnline))) {
                    if (!$IncludeOrphanedConfiguration) {
                        continue
                    }
                    $nObj.Warning.Add([WarningType]::GeneralFailure, 'Orphaned Network Object')
                }

                $Row = [E911DataRow]::new($nObj)
                $Row.ToString() | ConvertFrom-Json | Write-Output
            }

            $generatorHelper.Restart()
            $generatorHelper.Total = [E911ModuleState]::OnlineLocations.Count
            foreach ($location in [E911ModuleState]::OnlineLocations.Values) {
                $generatorHelper.Update($true, 'From Locations')
                if ($FoundLocationHashes.Contains($location.GetHash())) {
                    continue
                }
                [void]$FoundLocationHashes.Add($location.GetHash())
                if ($null -eq $location._address -or ($location._isOnline -and !$location._address._isOnline) -and !$IncludeOrphanedConfiguration) {
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
    
            $generatorHelper.Restart()
            $generatorHelper.Total = [E911ModuleState]::OnlineAddresses.Count
            foreach ($address in [E911ModuleState]::OnlineAddresses.Values) {

                $generatorHelper.Update($true, 'From Addresses')
                if ($FoundAddressHashes.Contains($address.GetHash())) {
                    continue
                }
                [void]$FoundAddressHashes.Add($address.GetHash())
                $Row = [E911DataRow]::new($address)
                $Row.ToString() | ConvertFrom-Json | Write-Output
            }
            $generatorHelper.WriteVerbose('Finished')
        }
        finally {
            if ($null -ne $commandHelper) {
                $commandHelper.Dispose()
            }
        }
    }
}