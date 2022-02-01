function Export-CsE911OnlineConfiguration {
    [CmdletBinding()]
    param ()

    begin {
        try {
            [Microsoft.TeamsCmdlets.Powershell.Connect.TeamsPowerShellSession]::ClientAuthenticated()
        }
        catch {
            throw "Run Connect-MicrosoftTeams prior to executing this script!"
        }

        # initialize caches
        $addressCache = @{}
        $locationCache = @{}
        $networkObjectCache = @{}
        $joinedItems = @{}

        Write-Verbose "Populating Caches..."
        try {
            $addressCache = Get-CsLisCivicAddressCache -ErrorAction Stop
            Write-Verbose "Cached $($addressCache.Keys.Count) Civic Addresses"
            $locationCache = Get-CsLisLocationCache -ErrorAction Stop
            Write-Verbose "Cached $($locationCache.Keys.Count) Locations"
            $networkObjectCache = Get-CsLisNetworkObjectCache -ErrorAction Stop
            Write-Verbose "Cached $($networkObjectCache.Keys.Count) Network Objects"
        }
        catch {
            throw $_
        }
    }

    process {
        foreach ($CivicAddress in $addressCache.Values) {
            if ($null -eq $CivicAddress) {
                Write-Warning "CivicAddress was null, skipping conversion."
                continue
            }
            $joinedItems.Add($CivicAddress, @{}) | Out-Null
        }

        # join locations to civic addresses
        foreach ($Location in $locationCache.Values) {
            if ($null -eq $Location) {
                Write-Warning "Location was null, skipping conversion."
                continue
            }
            $CivicAddress = $addressCache.Values | Where-Object { $_.CivicAddressId -eq $Location.CivicAddressId }
            if ($null -eq $CivicAddress) {
                Write-Warning "No CivicAddress with id of $($Location.CivicAddressId) was found, skipping conversion."
                continue
            }
            $joinedItems[$CivicAddress].Add($Location, @()) | Out-Null
        }

        # join network objects to locations
        foreach ($NetworkObject in $networkObjectCache.Values) {
            if ($null -eq $NetworkObject) {
                Write-Warning "NetworkObject was null, skipping conversion."
                continue
            }
            $Location = $locationCache.Values | Where-Object { $_.LocationId -eq $NetworkObject.LocationId }
            if ($null -eq $Location) {
                Write-Warning "No Location with id of $($NetworkObject.LocationId) was found, skipping conversion."
                continue
            }
            $CivicAddress = $joinedItems.Keys | Where-Object { $joinedItems[$_].ContainsKey($Location) }

            $joinedItems[$CivicAddress][$Location] += $NetworkObject
        }

        foreach ($CivicAddress in $joinedItems.Keys) {
            foreach ($Location in $joinedItems[$CivicAddress].Keys) {
                foreach ($NetworkObject in $joinedItems[$CivicAddress][$Location]) {
                    if ($NetworkObject.PortId) {
                        # port
                        $NetworkObjectType = 'Port'
                        $NetworkObjectIdentifier = @($NetworkObject.ChassisID, $NetworkObject.PortID) -join ';'
                    }
                    elseif ($NetworkObject.ChassisId) {
                        # switch
                        $NetworkObjectType = 'Switch'
                        $NetworkObjectIdentifier = $NetworkObject.ChassisId
                    }
                    elseif ($NetworkObject.Subnet) {
                        # Subnet
                        $NetworkObjectType = 'Subnet'
                        $NetworkObjectIdentifier = $NetworkObject.Subnet
                    }
                    elseif ($NetworkObject.Bssid) {
                        # WirelessAccessPoint
                        $NetworkObjectType = 'WirelessAccessPoint'
                        $NetworkObjectIdentifier = $NetworkObject.Bssid
                    }
                    else {
                        # return empty string if no match
                        $NetworkObjectType = 'Unknown'
                        $NetworkObjectIdentifier = ''
                    }

                    $NewAddress = [PSCustomObject]@{
                        CompanyName             = $CivicAddress.CompanyName
                        CompanyTaxId            = $CivicAddress.CompanyTaxId
                        Description             = $CivicAddress.CompanyName
                        Location                = $Location.Location
                        Address                 = (ConvertTo-CsE911AddressString -CivicAddress $CivicAddress)
                        City                    = $CivicAddress.City
                        StateOrProvince         = $CivicAddress.StateOrProvince
                        PostalCode              = $CivicAddress.PostalCode
                        CountryOrRegion         = $CivicAddress.CountryOrRegion
                        Latitude                = $CivicAddress.Latitude
                        Longitude               = $CivicAddress.Longitude
                        ELIN                    = $Location.ELIN
                        NetworkDescription      = $NetworkObject.Description
                        NetworkObjectType       = $NetworkObjectType
                        NetworkObjectIdentifier = $NetworkObjectIdentifier
                        SkipMapsLookup          = $false
                        EntryHash               = ''
                        Warning                 = ''
                    }

                    # Getting Hash because item already exists online
                    $EntryHash = Get-CsE911RowHash -Row $NewAddress
                    $NewAddress.EntryHash = $EntryHash
                    $NewAddress
                }
            }
        }
    }

    end {
    }
}

