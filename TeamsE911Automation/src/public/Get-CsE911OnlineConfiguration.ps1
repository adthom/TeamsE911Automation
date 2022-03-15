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
        }
        catch {
            throw "Run Connect-MicrosoftTeams prior to executing this script!"
        }

        # initialize caches
        $addressCache = @{}
        $locationCache = @{}
        $networkObjectCache = @{}
        $joinedItems = @{}

        if ($IncludeOrphanedConfiguration) {
            $OrphanedLocations = [Collections.Generic.List[object]]::new()
            $OrphanedNetworkObjects = [Collections.Generic.List[object]]::new()
            $OrphanedNetworkObjectsWithLocation = [Collections.Generic.List[object]]::new()
        }

        Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] Populating Caches..."
        try {
            $addressCache = Get-CsLisCivicAddressCache -ErrorAction Stop
            Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] Cached $($addressCache.Keys.Count) Civic Addresses"
            $locationCache = Get-CsLisLocationCache -PopulateUsageData -ErrorAction Stop
            Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] Cached $($locationCache.Keys.Count) Locations"
            $networkObjectCache = Get-CsLisNetworkObjectCache -ErrorAction Stop
            Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] Cached $($networkObjectCache.Keys.Count) Network Objects"
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
            $E911Address = ConvertTo-CsE911Address -LisAddress $Location
            $hashCode = Get-CsE911CivicAddressHashCode -Address $E911Address
            $CivicAddress = $addressCache[$hashCode]
            if ($null -eq $CivicAddress) {
                if ($IncludeOrphanedConfiguration -and !$OrphanedLocations.Contains($Location)) {
                    $OrphanedLocations.Add($Location) | Out-Null
                }
                else {
                    Write-Warning "No CivicAddress with id of $($Location.CivicAddressId) was found, skipping conversion. Use the 'IncludeOrphanedConfiguration' switch to include this data."
                }
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
                if ($IncludeOrphanedConfiguration -and !$OrphanedNetworkObjects.Contains($NetworkObject)) {
                    $OrphanedNetworkObjects.Add($NetworkObject) | Out-Null
                }
                else {
                    Write-Warning "No Location with id of $($NetworkObject.LocationId) was found, this object has been orphaned! Skipping conversion. Use the 'IncludeOrphanedConfiguration' switch to include this data."
                }
                continue
            }
            $E911Address = ConvertTo-CsE911Address -LisAddress $Location
            $hashCode = Get-CsE911CivicAddressHashCode -Address $E911Address
            $CivicAddress = $addressCache[$hashCode]
            if ($null -eq $CivicAddress) {
                if ($IncludeOrphanedConfiguration) {
                    if (!$OrphanedLocations.Contains($Location)) {
                        $OrphanedLocations.Add($Location) | Out-Null
                    }
                    $LocNetworkObject = [PSCustomObject]@{
                        NetworkObject = $NetworkObject
                        Location      = $Location
                    }
                    if (!$OrphanedNetworkObjectsWithLocation.Contains($LocNetworkObject)) {
                        $OrphanedNetworkObjectsWithLocation.Add($LocNetworkObject) | Out-Null
                    }
                }
                else {
                    Write-Warning "No CivicAddress was found, this location has been orphaned! Skipping conversion. Use the 'IncludeOrphanedConfiguration' switch to include this data."
                }
                continue
            }
            $joinedItems[$CivicAddress][$Location] += $NetworkObject
        }
        # add a blank network object for output if none was present
        $EmptyLocations = @()
        foreach ($CA in $joinedItems.Keys) {
            foreach ($Location in $joinedItems[$CA].Keys) {
                if ($joinedItems[$CA][$Location] -is [object[]] -and
                    $joinedItems[$CA][$Location].Count -eq 0 -and
                    ($Location.NumberOfVoiceUsers + $Location.NumberOfTelephoneNumbers -gt 0)) {
                    $EmptyLocations += $Location
                }
            }
        }
        foreach ($EmptyLocation in $EmptyLocations) {
            $CivicAddress = $joinedItems.Keys | Where-Object { $joinedItems[$_].ContainsKey($EmptyLocation) }
            $joinedItems[$CivicAddress][$EmptyLocation] += $null
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
                        SkipMapsLookup          = ![string]::IsNullOrEmpty($CivicAddress.Latitude) -and ![string]::IsNullOrEmpty($CivicAddress.Longitude) -and $CivicAddress.Latitude -ne 0 -and $CivicAddress.Longitude -ne 0
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
        if ($IncludeOrphanedConfiguration) {
            foreach ($Location in $OrphanedLocations) {
                if ($null -eq $Location) { continue }
                $NewAddress = [PSCustomObject]@{
                    CompanyName             = $Location.CompanyName
                    CompanyTaxId            = $Location.CompanyTaxId
                    Description             = $Location.CompanyName
                    Location                = $Location.Location
                    Address                 = (ConvertTo-CsE911AddressString -CivicAddress $Location)
                    City                    = $Location.City
                    StateOrProvince         = $Location.StateOrProvince
                    PostalCode              = $Location.PostalCode
                    CountryOrRegion         = $Location.CountryOrRegion
                    Latitude                = $Location.Latitude
                    Longitude               = $Location.Longitude
                    ELIN                    = $Location.ELIN
                    NetworkDescription      = ''
                    NetworkObjectType       = 'Unknown'
                    NetworkObjectIdentifier = ''
                    SkipMapsLookup          = ![string]::IsNullOrEmpty($Location.Latitude) -and ![string]::IsNullOrEmpty($Location.Longitude) -and $Location.Latitude -ne 0 -and $Location.Longitude -ne 0
                    EntryHash               = ''
                    Warning                 = 'ORPHANED'
                }

                # Getting Hash because item already exists online
                $EntryHash = Get-CsE911RowHash -Row $NewAddress
                $NewAddress.EntryHash = $EntryHash
                $NewAddress
            }
            foreach ($NetworkObject in $OrphanedNetworkObjects) {
                if ($null -eq $NetworkObject) { continue }
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
                    CompanyName             = ''
                    CompanyTaxId            = ''
                    Description             = ''
                    Location                = ''
                    Address                 = ''
                    City                    = ''
                    StateOrProvince         = ''
                    PostalCode              = ''
                    CountryOrRegion         = ''
                    Latitude                = ''
                    Longitude               = ''
                    ELIN                    = ''
                    NetworkDescription      = $NetworkObject.Description
                    NetworkObjectType       = $NetworkObjectType
                    NetworkObjectIdentifier = $NetworkObjectIdentifier
                    SkipMapsLookup          = $false
                    EntryHash               = ''
                    Warning                 = 'ORPHANED'
                }

                # Getting Hash because item already exists online
                $EntryHash = Get-CsE911RowHash -Row $NewAddress
                $NewAddress.EntryHash = $EntryHash
                $NewAddress
            }
            foreach ($NetworkObjectWithLocation in $OrphanedNetworkObjectsWithLocation) {
                if (!$OrphanedNetworkObjectsWithLocation.Contains($LocNetworkObject)) {
                    $OrphanedNetworkObjectsWithLocation.Add($LocNetworkObject) | Out-Null
                }
                $NetworkObject = $NetworkObjectWithLocation.NetworkObject
                $Location = $NetworkObjectWithLocation.Location
                if ($null -eq $NetworkObject) { continue }
                if ($null -eq $Location) { continue }
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
                    CompanyName             = $Location.CompanyName
                    CompanyTaxId            = $Location.CompanyTaxId
                    Description             = $Location.CompanyName
                    Location                = $Location.Location
                    Address                 = (ConvertTo-CsE911AddressString -CivicAddress $Location)
                    City                    = $Location.City
                    StateOrProvince         = $Location.StateOrProvince
                    PostalCode              = $Location.PostalCode
                    CountryOrRegion         = $Location.CountryOrRegion
                    Latitude                = $Location.Latitude
                    Longitude               = $Location.Longitude
                    ELIN                    = $Location.ELIN
                    NetworkDescription      = $NetworkObject.Description
                    NetworkObjectType       = $NetworkObjectType
                    NetworkObjectIdentifier = $NetworkObjectIdentifier
                    SkipMapsLookup          = ![string]::IsNullOrEmpty($Location.Latitude) -and ![string]::IsNullOrEmpty($Location.Longitude) -and $Location.Latitude -ne 0 -and $Location.Longitude -ne 0
                    EntryHash               = ''
                    Warning                 = 'ORPHANED'
                }

                # Getting Hash because item already exists online
                $EntryHash = Get-CsE911RowHash -Row $NewAddress
                $NewAddress.EntryHash = $EntryHash
                $NewAddress
            }
        }
    }

    end {
        $vsw.Stop()
        Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] Finished"
    }
}
