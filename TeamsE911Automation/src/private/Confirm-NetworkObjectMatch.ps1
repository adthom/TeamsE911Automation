function Confirm-NetworkObjectMatch {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        # Parameter help description
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $false)]
        [PSObject]
        $Cached,

        # Parameter help description
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSObject]
        $New,

        [hashtable]
        $LocationCache = @{}
    )

    begin {
        $DoesMatch = $true

        $MatchesProperties = @(
            "BSSID",
            "PortID"
            "ChassisID"
            "Subnet",
            "Description"
        )
    }

    process {
        # find location from cache by id
        $CachedLocation = $LocationCache.Values | Where-Object { $_.LocationId -eq $Cached.LocationId }
        if (!$CachedLocation) {
            Write-Verbose -Message "Cache Miss! Getting from Module..."
            $CachedLocation = Get-CsOnlineLisLocation -LocationId $Cached.LocationId -ErrorAction SilentlyContinue
        }

        # if we don't have a location entry, assume we need to recreate
        $DoesMatch = $DoesMatch -and $null -ne $CachedLocation

        # Convert CivicAddress to Address
        $DoesMatch = $DoesMatch -and (Confirm-LocationMatch -New $New -Cached $CachedLocation)

        for ($i = 0; $i -lt $MatchesProperties.Count; $i++) {
            $Property = $MatchesProperties[$i]
            $CachedValue = $Cached.$Property
            switch ($Property) {
                "Description" {
                    $NewProperty = "NetworkDescription"
                    $NewValue = $New.NetworkDescription
                    break
                }
                { $_ -eq "BSSID" -and $New.NetworkObjectType -eq 'WirelessAccessPoint' } {
                    $NewProperty = "NetworkObjectIdentifier (BSSID)"
                    $NewValue = ConvertTo-PhysicalAddressString -address $New.NetworkObjectIdentifier
                    break
                }
                { $_ -eq "Subnet" -and $New.NetworkObjectType -eq 'Subnet' } {
                    $NewProperty = "NetworkObjectIdentifier (Subnet)"
                    $NewValue = $New.NetworkObjectIdentifier
                    break
                }
                { $_ -eq "ChassisID" -and $New.NetworkObjectType -in @('Switch', 'Port') } {
                    $NewProperty = "NetworkObjectIdentifier (ChassisID)"
                    $ChassisId = ($New.NetworkObjectIdentifier -split ';', 2)[0]
                    $ParsedChassisId = ConvertTo-PhysicalAddressString -address $ChassisId
                    if ([string]::IsNullOrEmpty($ParsedChassisId)) {
                        $ChassisId = $ParsedChassisId
                    }
                    $NewValue = $ChassisId
                    break
                }
                { $_ -eq "PortID" -and $New.NetworkObjectType -eq 'Port' } {
                    $NewProperty = "NetworkObjectIdentifier (PortID)"
                    $NewValue = ($New.NetworkObjectIdentifier -split ';', 2)[1]
                    break
                }
                default {
                    $NewProperty = $Property
                    $NewValue = $New.$Property
                    break
                }
            }

            if (![string]::IsNullOrEmpty($CachedValue)) {
                $CachedValue = $CachedValue.ToLower().Trim()
            }
            else {
                $CachedValue = $null
            }
            if (![string]::IsNullOrEmpty($NewValue)) {
                $NewValue = $NewValue.ToLower().Trim()
            }
            else {
                $NewValue = $null
            }
            $PropertyDoesMatch = $CachedValue -eq $NewValue
            if (!$PropertyDoesMatch) {
                Write-Warning "Cached ${Property}: $CachedValue does not equal new ${NewProperty}: $NewValue"
            }
            $DoesMatch = $DoesMatch -and $PropertyDoesMatch
        }
        if (!$DoesMatch) {
            Write-Warning "NetworkObject must be updated!"
        }
    }

    end {
        return $DoesMatch
    }
}
