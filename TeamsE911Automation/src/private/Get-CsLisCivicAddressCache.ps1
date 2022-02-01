function Get-CsLisCivicAddressCache {
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
        $CivicAddressCache = @{}
        # assuming we have valid session, use my checks before hand
        $civicAddresses = Get-CsOnlineLisCivicAddress
        foreach ($civicAddress in $civicAddresses) {
            $address = ConvertTo-CsE911Address -LisAddress $civicAddress
            $hashCode = Get-CsE911CivicAddressHashCode -Address $address
            if ($null -eq $hashCode -or $CivicAddressCache.ContainsKey($hashCode)) {
                continue
            }
            $CivicAddressCache[$hashCode] = $civicAddress
        }
        return $CivicAddressCache
    }
    end {
    }
}

