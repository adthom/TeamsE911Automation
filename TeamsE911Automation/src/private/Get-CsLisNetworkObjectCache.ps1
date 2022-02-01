function Get-CsLisNetworkObjectCache {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param ()
    begin {
        try {
            [Microsoft.TeamsCmdlets.Powershell.Connect.TeamsPowerShellSession]::ClientAuthenticated()
        }
        catch {
            throw "Run Connect-MicrosoftTeams prior to executing this script!"
        }
    }
    process {
        $NetworkLocationCache = @{}
        # assuming we have valid session, use my checks before hand
        $networkObjects = 'Port', 'Subnet', 'Switch', 'WirelessAccessPoint' | ForEach-Object { (& "Get-CsOnlineLis$_") }
        foreach ($networkObject in $networkObjects) {
            $hashCode = Get-CsE911NetworkObjectHashCode $networkObject
            if ($null -eq $hashCode -or $NetworkLocationCache.ContainsKey($hashCode)) {
                continue
            }
            $NetworkLocationCache[$hashCode] = $networkObject
        }
        return $NetworkLocationCache
    }
    end {
    }
}

