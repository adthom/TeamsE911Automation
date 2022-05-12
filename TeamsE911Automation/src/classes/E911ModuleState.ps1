class E911ModuleState {
    static [int] $MapsQueryCount = 0
    static [void] ValidateAddress([E911Address] $Address) {
        if ($null -eq [E911ModuleState]::MapsKey()) {
            $Address.Warning.Add([WarningType]::MapsValidation, 'No Maps API Key Found')
            return
        }
        $QueryArgs = @{
            'subscription-key' = [E911ModuleState]::MapsKey()
            'api-version'      = '1.0'
            query              = [E911ModuleState]::_getAddressInMapsQueryForm($Address)
            limit              = 10
            countrySet         = $Address.CountryOrRegion
        }
        $Query = [Text.StringBuilder]::new()
        $JoinChar = '?'
        foreach ($Parameter in $QueryArgs.Keys) {
            if ($Query.Length -gt 1) {
                $JoinChar = '&'
            }
            $Value = $QueryArgs[$Parameter] -join ','
            [void]$Query.AppendFormat('{0}{1}={2}', $JoinChar, $Parameter, [System.Web.HttpUtility]::UrlEncode($Value))
        }
        try {
            [E911ModuleState]::MapsQueryCount++
            $CleanUri = '{0}{1}' -f [E911ModuleState]::MapsClient().BaseAddress, $Query.ToString()
            $CleanUri = $CleanUri -replace [Regex]::Escape([E911ModuleState]::MapsKey()), '<APIKEY REDACTED>'
            Write-Debug $CleanUri
            $responseString = [E911ModuleState]::MapsClient().GetStringAsync($Query.ToString()).Result
            $Response = ''
            if (![string]::IsNullOrEmpty($responseString)) {
                $Response = $responseString | ConvertFrom-Json
            }
            if ([string]::IsNullOrEmpty($Response)) {
                throw "$CleanUri Produced no results!"
                return
            }
        }
        catch {
            $Address.Warning.Add([WarningType]::MapsValidation, "Maps API failure: $($_.Exception.Message)")
            return
        }

        $AzureMapsAddress = if ( $Response.summary.totalResults -gt 0 ) {
            $MapsAddress = @($Response.results | Sort-Object -Property score -Descending).Where({ $_.type -in @('Point Address', 'Address Range') }, 'First', 1)[0]
            if ($null -eq $MapsAddress) {
                return
            }
            $PostalOrZipCode = switch ($MapsAddress.address.countryCode) {
                { $_ -in @("CA", "IE", "GB", "PT") } {
                    if ([string]::IsNullOrEmpty($Address.address.extendedPostalCode)) {
                        $MapsAddress.address.postalCode
                    }
                    else {
                        $MapsAddress.address.extendedPostalCode
                    }
                }
                default {
                    $MapsAddress.address.postalCode
                }
            }
            [PSCustomObject]@{
                HouseNumber     = $MapsAddress.address.streetNumber
                StreetName      = ($MapsAddress.address.streetName -split ',')[0]
                City            = ($MapsAddress.address.municipality -split ',')[0]
                StateOrProvince = $MapsAddress.address.countrySubdivision
                PostalCode      = $PostalOrZipCode
                Country         = $MapsAddress.address.countryCode
                Latitude        = $MapsAddress.position.lat
                Longitude       = $MapsAddress.position.lon
            }
        }
        if (!$AzureMapsAddress) {
            Write-Debug ($Response | ConvertTo-Json -Compress)
        }
        $MapResultString = $($AzureMapsAddress | ConvertTo-Json -Compress)
        $ResultFound = ![string]::IsNullOrEmpty($MapResultString)
        if (!$ResultFound) {
            $Address.Warning.Add([WarningType]::MapsValidation, "Location was not found by Azure Maps!")
        }
        $Warned = $false
        # write warnings for changes from input
        $AzureAddress = "{0} {1}" -f $AzureMapsAddress.HouseNumber, $AzureMapsAddress.StreetName
        if ($ResultFound -and $Address.Address -ne $AzureAddress) {
            $Address.Warning.Add([WarningType]::MapsValidation, "Provided Address: '$($Address.Address)' does not match Azure Maps Address: '$($AzureAddress)'!")
            $Warned = $true
        }
        if ($ResultFound -and $Address.City -ne $AzureMapsAddress.City) {
            $Address.Warning.Add([WarningType]::MapsValidation, "Provided City: '$($Address.City)' does not match Azure Maps City: '$($AzureMapsAddress.City)'!")
            $Warned = $true
        }
        if ($ResultFound -and $Address.StateOrProvince -ne $AzureMapsAddress.StateOrProvince) {
            $Address.Warning.Add([WarningType]::MapsValidation, "Provided StateOrProvince: '$($Address.StateOrProvince)' does not match Azure Maps StateOrProvince: '$($AzureMapsAddress.StateOrProvince)'!")
            $Warned = $true
        }
        if ($ResultFound -and $Address.PostalCode -ne $AzureMapsAddress.PostalCode) {
            $Address.Warning.Add([WarningType]::MapsValidation, "Provided PostalCode: '$($Address.PostalCode)' does not match Azure Maps PostalCode: '$($AzureMapsAddress.PostalCode)'!")
            $Warned = $true
        }
        if ($ResultFound -and $Address.CountryOrRegion -ne $AzureMapsAddress.Country) {
            $Address.Warning.Add([WarningType]::MapsValidation, "Provided Country: '$($Address.CountryOrRegion)' does not match Azure Maps Country: '$($AzureMapsAddress.Country)'!")
            $Warned = $true
        }
        if ($ResultFound -and ![string]::IsNullOrEmpty($Address.Latitude) -and ![string]::IsNullOrEmpty($Address.Longitude) -and $Address.Latitude -ne 0 -and $Address.Longitude -ne 0) {
            if (![E911ModuleState]::CompareDoubleFuzzy($Address.Latitude, $AzureMapsAddress.Latitude)) {
                $Address.Warning.Add([WarningType]::MapsValidation, "Provided Latitude: '$($Address.Latitude)' does not match Azure Maps Latitude: '$($AzureMapsAddress.Latitude)'!")
                $Warned = $true
            }
            if (![E911ModuleState]::CompareDoubleFuzzy($Address.Longitude, $AzureMapsAddress.Longitude)) {
                $Address.Warning.Add([WarningType]::MapsValidation, "Provided Longitude: '$($Address.Longitude)' does not match Azure Maps Longitude: '$($AzureMapsAddress.Longitude)'!")
                $Warned = $true
            }
        }
        if ($ResultFound -and [string]::IsNullOrEmpty($Address.Latitude) -or [string]::IsNullOrEmpty($Address.Longitude) -or ($Address.Latitude -eq 0 -and $Address.Longitude -eq 0)) {
            $Address.Latitude = $AzureMapsAddress.Latitude
            $Address.Longitude = $AzureMapsAddress.Longitude
        }
        if ($ResultFound -and $Warned) {
            $Address.Warning.Add([WarningType]::MapsValidationDetail, "AzureMapsAddress: $($AzureMapsAddress | ConvertTo-Json -Compress)")
        }
    }

    static [bool] $WriteWarnings = $false

    hidden static [System.Collections.Generic.Dictionary[string, E911Address]] $OnlineAddresses = [System.Collections.Generic.Dictionary[string, E911Address]]::new()
    hidden static [System.Collections.Generic.Dictionary[string, E911Address]] $Addresses = [System.Collections.Generic.Dictionary[string, E911Address]]::new()
    hidden static [System.Collections.Generic.Dictionary[string, E911Location]] $OnlineLocations = [System.Collections.Generic.Dictionary[string, E911Location]]::new()
    hidden static [System.Collections.Generic.Dictionary[string, E911Location]] $Locations = [System.Collections.Generic.Dictionary[string, E911Location]]::new()
    hidden static [System.Collections.Generic.Dictionary[string, E911NetworkObject]] $OnlineNetworkObjects = [System.Collections.Generic.Dictionary[string, E911NetworkObject]]::new()
    hidden static [System.Collections.Generic.Dictionary[string, E911NetworkObject]] $NetworkObjects = [System.Collections.Generic.Dictionary[string, E911NetworkObject]]::new()

    static [E911Address] GetOrCreateAddress([PSCustomObject] $obj, [bool] $ShouldValidate) {
        $Hash = [E911Address]::GetHash($obj)
        $Test = $null
        if ([E911ModuleState]::Addresses.ContainsKey($Hash)) {
            $Test = [E911ModuleState]::Addresses[$Hash]
            if ($Test.Warning.MapsValidationFailed() -or $null -eq $obj.SkipMapsLookup -or !$Test.SkipMapsLookup -or $obj.SkipMapsLookup -eq $Test.SkipMapsLookup) {
                return $Test
            }
        }
        $OnlineChanged = $false
        $Online = $null
        if (![string]::IsNullOrEmpty($obj.CivicAddressId) -and [E911ModuleState]::OnlineAddresses.ContainsKey($obj.CivicAddressId.ToLower())) {
            $Online = [E911ModuleState]::OnlineAddresses[$obj.CivicAddressId.ToLower()]
            if ([E911Address]::Equals($Online, $obj)) {
                return $Online
            }
            $OnlineChanged = $true
        }
        if ($null -eq $Online -and [E911ModuleState]::OnlineAddresses.ContainsKey($Hash)) {
            $Online = [E911ModuleState]::OnlineAddresses[$Hash]
            if ([E911Address]::Equals($Online, $obj)) {
                if (![string]::IsNullOrEmpty($obj.CivicAddressId)) {
                    # found a duplicate online address, lets add this address id here so we can link this up later
                    [E911ModuleState]::OnlineAddresses.Add($obj.CivicAddressId.ToLower(), $Online)
                }
                return $Online
            }
            $OnlineChanged = $true
        }
        $New = [E911Address]::new($obj, $ShouldValidate)
        if ($null -ne $Test) {
            if ($New.HasWarnings()) {
                $Test.Warning.AddRange($New.Warning)
            }
            $Test.Latitude = if ($Test.Latitude -eq 0) { $New.Latitude } else { $Test.Latitude }
            $Test.Longitude = if ($Test.Longitude -eq 0) { $New.Longitude } else { $Test.Longitude }
            $Test.SkipMapsLookup = $false
            $Test._hasChanged = $true
            [E911ModuleState]::Addresses[$Test.GetHash()] = $Test
            if ($Test._isOnline -and $OnlineChanged) {
                [E911ModuleState]::OnlineAddresses[$Test.GetHash()] = $Test
                [E911ModuleState]::OnlineAddresses[$Test.Id.ToString().ToLower()] = $Test
            }
            return $Test
        }
        if ((!$New._isOnline -and $ShouldValidate) -or $OnlineChanged) {
            $New._hasChanged = $true
            [E911ModuleState]::Addresses.Add($New.GetHash(), $New)
        }
        if ($OnlineChanged) {
            [E911ModuleState]::OnlineAddresses[$New.GetHash()] = $New
            [E911ModuleState]::OnlineAddresses[$New.Id.ToString().ToLower()] = $New
        }
        if ($New._isOnline -and !$OnlineChanged) {
            [E911ModuleState]::OnlineAddresses.Add($New.GetHash(), $New)
            [E911ModuleState]::OnlineAddresses.Add($New.Id.ToString().ToLower(), $New)
        }
        return $New
    }
    static [E911Location] GetOrCreateLocation([PSCustomObject] $obj, [bool]$ShouldValidate) {
        $OnlineChanged = $false
        $Online = $null
        if (![string]::IsNullOrEmpty($obj.LocationId) -and [E911ModuleState]::OnlineLocations.ContainsKey($obj.LocationId.ToLower())) {
            $Online = [E911ModuleState]::OnlineLocations[$obj.LocationId.ToLower()]
            if (([string]::IsNullOrEmpty($obj.Location) -and [string]::IsNullOrEmpty($obj.CountryOrRegion)) -or [E911Location]::Equals($Online, $obj)) {
                return $Online
            }
            # not sure we should ever get here...
            $OnlineChanged = $true
        }
        if (!$OnlineChanged -and ![string]::IsNullOrEmpty($obj.DefaultLocationId) -and [E911ModuleState]::OnlineLocations.ContainsKey($obj.DefaultLocationId.ToLower())) {
            $Online = [E911ModuleState]::OnlineLocations[$obj.DefaultLocationId.ToLower()]
            if ([E911Location]::Equals($Online, $obj)) {
                return $Online
            }
            # not sure we should ever get here...
            $OnlineChanged = $true
        }
        $Hash = [E911Location]::GetHash($obj)
        if ([E911ModuleState]::Locations.ContainsKey($Hash)) {
            return [E911ModuleState]::Locations[$Hash]
        }
        if ($null -eq $Online -and [E911ModuleState]::OnlineLocations.ContainsKey($Hash)) {
            $Online = [E911ModuleState]::OnlineLocations[$Hash]
            if ([E911Location]::Equals($Online, $obj)) {
                if (![string]::IsNullOrEmpty($obj.LocationId)) {
                    # found a duplicate online location, lets add this location id here so we can link this up later
                    [E911ModuleState]::OnlineLocations.Add($obj.LocationId.ToLower(), $Online)
                }
                return $Online
            }
            $OnlineChanged = $true
        }
        $New = [E911Location]::new($obj, $ShouldValidate)
        if ((!$New._isOnline -and $ShouldValidate) -or $OnlineChanged) {
            $New._hasChanged = $true
            [E911ModuleState]::Locations.Add($New.GetHash(), $New)
        }
        if ($OnlineChanged) {
            $New._hasChanged = $true
            [E911ModuleState]::OnlineLocations[$New.GetHash()] = $New
            [E911ModuleState]::OnlineLocations[$New.Id.ToString().ToLower()] = $New
        }
        if ($New._isOnline -and !$OnlineChanged) {
            if (![E911ModuleState]::OnlineLocations.ContainsKey($New.GetHash())) {
                [E911ModuleState]::OnlineLocations.Add($New.GetHash(), $New)
                [E911ModuleState]::OnlineLocations.Add($New.Id.ToString().ToLower(), $New)
            }
            else {
                [E911ModuleState]::OnlineLocations.Add($New.Id.ToString().ToLower(), [E911ModuleState]::OnlineLocations[$New.GetHash()])
            }
        }
        return $New
    }
    static [E911NetworkObject] GetOrCreateNetworkObject([PSCustomObject] $obj, [bool]$ShouldValidate) {
        $Hash = [E911NetworkObject]::GetHash($obj)
        $dup = $false
        if ([E911ModuleState]::NetworkObjects.ContainsKey($Hash)) {
            $Test = [E911ModuleState]::NetworkObjects[$Hash]
            if ([E911Location]::Equals($obj, $Test.Location)) {
                return $Test
            }
            $dup = $true
            $Test._isDuplicate = $true
            $Test.Warning.Add([WarningType]::DuplicateNetworkObject, "$($Test.Type):$($Test.Identifier) exists in other rows")
        }
        $OnlineChanged = $false
        if ([E911ModuleState]::OnlineNetworkObjects.ContainsKey($Hash)) {
            $Online = [E911ModuleState]::OnlineNetworkObjects[$Hash]
            if ([E911NetworkObject]::Equals($Online, $obj)) {
                if ($dup) {
                    $Online.Warning.Add([WarningType]::DuplicateNetworkObject, "$($Online.Type):$($Online.Identifier) exists in other rows")
                }
                return $Online
            }
            $OnlineChanged = $true
        }
        $New = [E911NetworkObject]::new($obj, $ShouldValidate)
        if ($dup) {
            $New.Warning.Add([WarningType]::DuplicateNetworkObject, "$($New.Type):$($New.Identifier) exists in other rows")
        }
        if (!$dup -and $New.Type -ne [NetworkObjectType]::Unknown -and ((!$New._isOnline -and $ShouldValidate) -or $OnlineChanged)) {
            $New._hasChanged = $true
            [E911ModuleState]::NetworkObjects.Add($New.GetHash(), $New)
            if ($Hash -ne $New.GetHash()) {
                [E911ModuleState]::NetworkObjects.Add($Hash, $New)
            }
        }
        if ($OnlineChanged) {
            $New._hasChanged = $true
            [E911ModuleState]::OnlineNetworkObjects[$New.GetHash()] = $New
            if ($Hash -ne $New.GetHash()) {
                [E911ModuleState]::OnlineNetworkObjects[$Hash] = $New
            }
        }
        if ($New._isOnline -and !$OnlineChanged) {
            [E911ModuleState]::OnlineNetworkObjects.Add($New.GetHash(), $New)
            if ($Hash -ne $New.GetHash()) {
                [E911ModuleState]::OnlineNetworkObjects.Add($Hash, $New)
            }
        }
        return $New
    }

    static [bool] $ForceOnlineCheck = $false
    # this is set to false after first caching run, then set to true after processing first online change in Set-CsE911OnlineChange
    static hidden [bool] $ShouldClear = $true

    static [void] FlushCaches([Diagnostics.Stopwatch] $vsw) {
        $shouldstop = $false
        if ($null -eq $vsw) {
            $vsw = [Diagnostics.Stopwatch]::StartNew()
            $shouldstop = $true
        }
        [E911ModuleState]::MapsQueryCount = 0
        $CommandName = [E911ModuleState]::GetCommandName()
        Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$CommandName] Flushing Caches..."
        $OnlineAddrCount = [E911ModuleState]::OnlineAddresses.Count
        $AddrCount = [E911ModuleState]::Addresses.Count
        $OnlineLocCount = [E911ModuleState]::OnlineLocations.Count
        $LocCount = [E911ModuleState]::Locations.Count
        $OnlineNobjCount = [E911ModuleState]::OnlineNetworkObjects.Count
        $NobjCount = [E911ModuleState]::NetworkObjects.Count
        [E911ModuleState]::OnlineAddresses.Clear()
        Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$CommandName] $($OnlineAddrCount - [E911ModuleState]::OnlineAddresses.Count) Online Addresses Removed"
        [E911ModuleState]::Addresses.Clear()
        Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$CommandName] $($AddrCount - [E911ModuleState]::Addresses.Count) Addresses Removed"
        [E911ModuleState]::OnlineLocations.Clear()
        Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$CommandName] $($OnlineLocCount - [E911ModuleState]::OnlineLocations.Count) Online Locations Removed"
        [E911ModuleState]::Locations.Clear()
        Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$CommandName] $($LocCount - [E911ModuleState]::Locations.Count) Locations Removed"
        [E911ModuleState]::OnlineNetworkObjects.Clear()
        Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$CommandName] $($OnlineNobjCount - [E911ModuleState]::OnlineNetworkObjects.Count) Online Network Objects Removed"
        [E911ModuleState]::NetworkObjects.Clear()
        Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$CommandName] $($NobjCount - [E911ModuleState]::NetworkObjects.Count) Network Objects Removed"
        [E911ModuleState]::ShouldClear = $false
        if ($shouldstop) {
            $vsw.Stop()
        }
    }

    hidden static [string] GetCommandName() {
        $CallStack = Get-PSCallStack
        $CommandName = $CallStack.Command
        $IgnoreNames = @([E911ModuleState].DeclaredMethods.Name | Sort-Object -Unique)
        $IgnoreNames += '<ScriptBlock>'
        if ($CommandName.Count -gt 1) {
            $CommandName = $CommandName | Where-Object { ![string]::IsNullOrEmpty($_) -and $_ -notin $IgnoreNames -and $_ -match '(?=^[^-]*-[^-]*$)' } | Select-Object -First 1
        }
        if ([string]::IsNullOrEmpty($CommandName)) {
            $CommandName = $CallStack.FunctionName | Where-Object { ![string]::IsNullOrEmpty($_) -and $_ -notin $IgnoreNames -and $_ -match '^E911' } | Select-Object -First 1
        }
        if ([string]::IsNullOrEmpty($CommandName)) {
            $CommandName = $CallStack.Command | Where-Object { ![string]::IsNullOrEmpty($_) -and $_ -notin $IgnoreNames } | Select-Object -First 1
        }
        return $CommandName
    }

    hidden static [int] $Interval = 200

    static [void] InitializeCaches([Diagnostics.Stopwatch] $vsw) {
        $shouldstop = $false
        if ($null -eq $vsw) {
            $vsw = [Diagnostics.Stopwatch]::StartNew()
            $shouldstop = $true
        }
        $CommandName = [E911ModuleState]::GetCommandName()
        if ([E911ModuleState]::ShouldClear) {
            [E911ModuleState]::FlushCaches($vsw)
        }
        if (([E911ModuleState]::Addresses.Count + [E911ModuleState]::Locations.Count + [E911ModuleState]::NetworkObjects.Count) -gt 0) {
            if ($shouldstop) {
                $vsw.Stop()
            }
            return
        }
        Write-Progress -Activity 'Caching Online Configuration' -Id 0
        Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$CommandName] Populating Caches..."
        Write-Progress -Activity 'Caching Online Configuration' -Id 0 -Status 'Getting Addresses'
        $oAddresses = Get-CsOnlineLisCivicAddress
        $shouldp = $true
        $LastMilliseconds = $vsw.Elapsed.TotalMilliseconds
        for ($i = 0; $i -lt $oAddresses.Count; $i++) {
            if (!$shouldp -and ($vsw.Elapsed.TotalMilliseconds - $LastMilliseconds) -ge [E911ModuleState]::Interval) { $shouldp = $true }
            if ($i -eq 0 -or ($shouldp -and ($vsw.Elapsed.TotalMilliseconds - $LastMilliseconds) -ge [E911ModuleState]::Interval)) {
                if ($i -gt 0) { $shouldp = $false }
                $ProgressParams = @{
                    Activity        = 'Caching Online Configuration'
                    Status          = 'Caching Addresses: [{0:F3}s] ({1}/{2})' -f $vsw.Elapsed.TotalSeconds, $i, $oAddresses.Count
                    Id              = 0
                    PercentComplete = [int](($i / $oAddresses.Count) * 100)
                }
                $LastMilliseconds = $vsw.Elapsed.TotalMilliseconds
                Write-Progress @ProgressParams
            }
            $oAddress = $oAddresses[$i]
            try {
                Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$CommandName] Caching Address: $($oAddress.CivicAddressId)..."
                [void][E911ModuleState]::GetOrCreateAddress($oAddress, $false)
            }
            catch {
                Write-Warning "Address: $($oAddress.CivicAddressId) could not be cached: $($_.Exception.Message) Line: '$($_.InvocationInfo.Line)'"
            }
        }
        Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$CommandName] Cached $($oAddresses.Count) Civic Addresses"
        Write-Progress -Activity 'Caching Online Configuration' -Id 0 -Status 'Getting Locations'
        $oLocations = Get-CsOnlineLisLocation
        $shouldp = $true
        $LastMilliseconds = $vsw.Elapsed.TotalMilliseconds
        for ($i = 0; $i -lt $oLocations.Count; $i++) {
            if (!$shouldp -and ($vsw.Elapsed.TotalMilliseconds - $LastMilliseconds) -ge [E911ModuleState]::Interval) { $shouldp = $true }
            if ($i -eq 0 -or ($shouldp -and ($vsw.Elapsed.TotalMilliseconds - $LastMilliseconds) -ge [E911ModuleState]::Interval)) {
                if ($i -gt 0) { $shouldp = $false }
                $ProgressParams = @{
                    Activity        = 'Caching Online Configuration'
                    Status          = 'Caching Locations: [{0:F3}s] ({1}/{2})' -f $vsw.Elapsed.TotalSeconds, $i, $oLocations.Count
                    Id              = 0
                    PercentComplete = [int](($i / $oLocations.Count) * 100)
                }
                $LastMilliseconds = $vsw.Elapsed.TotalMilliseconds
                Write-Progress @ProgressParams
            }
            $oLocation = $oLocations[$i]
            try {
                Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$CommandName] Caching Location: $($oLocation.LocationId)..."
                [void][E911ModuleState]::GetOrCreateLocation($oLocation, $false)
            }
            catch {
                Write-Warning "Location: $($oLocation.LocationId) could not be cached: $($_.Exception.Message) Line: '$($_.InvocationInfo.Line)'"
            }
        }
        Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$CommandName] Cached $($oLocations.Count) Locations"
        $nObjectCount = 0
        foreach ($n in [Enum]::GetNames([NetworkObjectType])) {
            if ($n -eq 'Unknown') { continue }
            $name = $n
            if ($name -eq 'Switch') { $name += 'e' }
            Write-Progress -Activity 'Caching Online Configuration' -Id 0 -Status "Getting ${name}s" -PercentComplete 0
            $oObjects = Invoke-Command -NoNewScope ([ScriptBlock]::Create(('Get-CsOnlineLis{0}' -f $n)))
            $nObjectCount += $oObjects.Count
            $shouldp = $true
            $LastMilliseconds = $vsw.Elapsed.TotalMilliseconds
            for ($i = 0; $i -lt $oObjects.Count; $i++) {
                if (!$shouldp -and ($vsw.Elapsed.TotalMilliseconds - $LastMilliseconds) -ge [E911ModuleState]::Interval) { $shouldp = $true }
                if ($i -eq 0 -or ($shouldp -and ($vsw.Elapsed.TotalMilliseconds - $LastMilliseconds) -ge [E911ModuleState]::Interval)) {
                    if ($i -gt 0) { $shouldp = $false }
                    $ProgressParams = @{
                        Activity        = 'Caching Online Configuration'
                        Status          = 'Caching {0}s: [{1:F3}s] ({2}/{3})' -f $name, $vsw.Elapsed.TotalSeconds, $i, $oObjects.Count
                        Id              = 0
                        PercentComplete = [int](($i / $oObjects.Count) * 100)
                    }
                    $LastMilliseconds = $vsw.Elapsed.TotalMilliseconds
                    Write-Progress @ProgressParams
                }
                $oObject = $oObjects[$i]
                $Id = if ($null -ne $oObject.Bssid) { 
                    $oObject.Bssid
                } 
                elseif ($null -ne $oObject.Subnet) {
                    $oObject.Subnet
                }
                else { 
                    "$($oObject.ChassisId)$(if($null -ne $oObject.PortId){";$($oObject.PortId)"})"
                }
                try {
                    Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$CommandName] Caching ${n}: $Id..."
                    [void][E911ModuleState]::GetOrCreateNetworkObject($oObject, $false)
                }
                catch {
                    Write-Warning "${n}: $Id could not be cached: $($_.Exception.Message) Line: '$($_.InvocationInfo.Line)'"
                }
            }
        }
        if ($shouldstop) {
            $vsw.Stop()
        }
        Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$CommandName] Cached $nObjectCount Network Objects"
        Write-Progress -Activity 'Caching Online Configuration' -Id 0 -Completed
    }

    hidden static [string] $_azureMapsApiKey
    hidden static [System.Net.Http.HttpClient] $_mapsClient
    hidden static [string] MapsKey() {
        if ([string]::IsNullOrEmpty([E911ModuleState]::_azureMapsApiKey) -and ![string]::IsNullOrEmpty($env:AZUREMAPS_API_KEY) -and $env:AZUREMAPS_API_KEY -ne [E911ModuleState]::_azureMapsApiKey) {
            [E911ModuleState]::_azureMapsApiKey = $env:AZUREMAPS_API_KEY
        }
        return [E911ModuleState]::_azureMapsApiKey
    }
    hidden static [System.Net.Http.HttpClient] MapsClient() {
        if ($null -eq [E911ModuleState]::_mapsClient) {
            
            [E911ModuleState]::_mapsClient = [System.Net.Http.HttpClient]::new()
            [E911ModuleState]::_mapsClient.BaseAddress = 'https://atlas.microsoft.com/search/address/json'
        }
        return [E911ModuleState]::_mapsClient
    }
    hidden static [int] $_geocodeDecimalPlaces = 3
    hidden static [bool] CompareDoubleFuzzy([double] $ReferenceNum, [double] $DifferenceNum) {
        $Delta = [Math]::Abs($ReferenceNum - $DifferenceNum)
        $FmtString = [string]::new("0", [E911ModuleState]::_geocodeDecimalPlaces)
        $IsFuzzyMatch = [Math]::Round($Delta, [E911ModuleState]::_geocodeDecimalPlaces) -eq 0
        if (!$IsFuzzyMatch -and $ReferenceNum -ne 0.0) {
            Write-Debug ("ReferenceNum: {0:0.$FmtString}`tDifferenceNum: {1:0.$FmtString}`tDiff: {2:0.$FmtString}" -f $ReferenceNum, $DifferenceNum, $Delta)
        }
        return $IsFuzzyMatch
    }
    hidden static [string] _getAddressInMapsQueryForm([E911Address] $Address) {
        $sb = [Text.StringBuilder]::new()
        [void]$sb.Append($Address.Address)
        [void]$sb.Append(' ')
        [void]$sb.Append($Address.City)
        [void]$sb.Append(' ')
        [void]$sb.Append($Address.StateOrProvince)
        if (![string]::IsNullOrEmpty($Address.PostalCode)) {
            [void]$sb.Append(' ')
            [void]$sb.Append($Address.PostalCode)
        }
        return $sb.ToString()
    }
}
