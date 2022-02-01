function Get-CsLisLocationCache {
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
        $LocationCache = @{}
        # assuming we have valid session, use my checks before hand
        $locations = Get-CsOnlineLisLocation
        foreach ($location in $locations) {
            $address = ConvertTo-CsE911Address -LisAddress $location
            $hashCode = Get-CsE911LocationHashCode -Address $address -Location $location.Location
            if ($null -eq $hashCode -or $LocationCache.ContainsKey($hashCode)) {
                continue
            }
            $LocationCache[$hashCode] = $location
        }
        return $LocationCache
    }
    end {
    }
}
