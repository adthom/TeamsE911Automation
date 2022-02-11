function Get-CsLisLocationCache {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param (
        [switch]
        $PopulateUsageData
    )
    begin {
        try {
            [Microsoft.TeamsCmdlets.Powershell.Connect.TeamsPowerShellSession]::ClientAuthenticated()
        }
        catch {
            throw "Run Connect-MicrosoftTeams prior to executing this script!"
        }
        $LocationParams = @{
            ResultSize = [Int32]::MaxValue
        }
        if ($PopulateUsageData) {
            $LocationParams.PopulateNumberOfTelephoneNumbers = $true
            $LocationParams.PopulateNumberOfVoiceUsers = $true
        }
    }
    process {
        $LocationCache = @{}
        # assuming we have valid session, use my checks before hand
        $locations = Get-CsOnlineLisLocation @LocationParams
        foreach ($location in $locations) {
            $address = ConvertTo-CsE911Address -LisAddress $location
            $locationKey = $location.Location
            if ($PopulateUsageData) {
                $locationKey += $location.LocationId
            }
            $hashCode = Get-CsE911LocationHashCode -Address $address -Location $locationKey
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

