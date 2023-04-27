using module '..\..\modules\TeamsE911Internal\bin\release\TeamsE911Internal\TeamsE911Internal.psd1'
using module '..\..\modules\PSClassExtensions\bin\release\PSClassExtensions\PSClassExtensions.psd1'
using namespace System.Collections.Generic

class E911ModuleState {
    static [AddressValidator] $AddressValidator = [AddressValidator]::new()

    static [bool] $WriteWarnings = $false

    hidden static [Dictionary[string, E911Address]] $OnlineAddresses = @{}
    hidden static [Dictionary[string, E911Address]] $Addresses = @{}
    hidden static [Dictionary[string, E911Location]] $OnlineLocations = @{}
    hidden static [Dictionary[string, E911Location]] $Locations = @{}
    hidden static [Dictionary[string, E911NetworkObject]] $OnlineNetworkObjects = @{}
    hidden static [Dictionary[string, E911NetworkObject]] $NetworkObjects = @{}

    static [E911Address] GetOrCreateAddress([PSCustomObject] $obj, [bool] $ShouldValidate) {
        $Hash = [E911Address]::GetHash($obj)
        $Test = $null
        if ([E911ModuleState]::Addresses.TryGetValue($Hash, [ref] $Test)) {
            $Equal = [E911Address]::Equals($Test, $obj)
            if ($Equal -and ($Test.Warning.MapsValidationFailed() -or $null -eq $obj.SkipMapsLookup -or !$Test.SkipMapsLookup -or $obj.SkipMapsLookup -eq $Test.SkipMapsLookup)) {
                return $Test
            }
            if (!$Equal) {
                # not a true match, we will force this one to be created
                $Test = $null
            }
        }
        $OnlineChanged = $false
        $Online = $null
        if (![string]::IsNullOrEmpty($obj.CivicAddressId) -and [E911ModuleState]::OnlineAddresses.TryGetValue($obj.CivicAddressId.ToLower(), [ref] $Online)) {
            if ([E911Address]::Equals($Online, $obj)) {
                return $Online
            }
            $OnlineChanged = $true
        }
        if ($null -eq $Online -and [E911ModuleState]::OnlineAddresses.TryGetValue($Hash, [ref] $Online)) {
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
        if ($New.GetHash() -ne $Hash) { throw 'Address Hash Functions do not match!' }
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
        return $New
    }

    static [E911Location] GetOrCreateLocation([PSCustomObject] $obj, [bool]$ShouldValidate) {
        $OnlineChanged = $false
        $Online = $null
        if (![string]::IsNullOrEmpty($obj.LocationId) -and [E911ModuleState]::OnlineLocations.TryGetValue($obj.LocationId.ToLower(), [ref] $Online)) {
            if (([string]::IsNullOrEmpty($obj.Location) -and [string]::IsNullOrEmpty($obj.CountryOrRegion)) -or [E911Location]::Equals($Online, $obj)) {
                return $Online
            }
            # not sure we should ever get here...
            $OnlineChanged = $true
        }
        $Hash = [E911Location]::GetHash($obj)
        $Temp = $null
        if ([E911ModuleState]::Locations.TryGetValue($Hash, [ref] $Temp) -and [E911Location]::Equals($Temp, $obj)) {
            return $Temp
        }
        if ($null -eq $Online -and [E911ModuleState]::OnlineLocations.TryGetValue($Hash, [ref] $Online)) {
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
        if ($New.GetHash() -ne $Hash) { throw 'Location Hash Functions do not match!' }
        if ((!$New._isOnline -and $ShouldValidate) -or $OnlineChanged) {
            $New._hasChanged = $true
            [E911ModuleState]::Locations.Add($New.GetHash(), $New)
        }
        if ($OnlineChanged) {
            $New._hasChanged = $true
            [E911ModuleState]::OnlineLocations[$New.GetHash()] = $New
            [E911ModuleState]::OnlineLocations[$New.Id.ToString().ToLower()] = $New
        }
        return $New
    }

    static [E911NetworkObject] GetOrCreateNetworkObject([PSCustomObject] $obj, [bool]$ShouldValidate) {
        $Hash = [E911NetworkObject]::GetHash($obj)
        $dup = $false
        $Test = $null
        if ([E911ModuleState]::NetworkObjects.TryGetValue($Hash, [ref] $Test)) {
            if ([E911Location]::Equals($obj, $Test._location)) {
                return $Test
            }
            if ($Test.Type -ne [NetworkObjectType]::Unknown) {
                $dup = $true
                $Test._isDuplicate = $true
                $Test.Warning.Add([WarningType]::DuplicateNetworkObject, "$($Test.Type):$($Test.Identifier) exists in other rows 126")
            }
        }
        $OnlineChanged = $false
        $Online = $null
        if ([E911ModuleState]::OnlineNetworkObjects.TryGetValue($Hash, [ref] $Online)) {
            if ([E911NetworkObject]::Equals($Online, $obj)) {
                if ($dup) {
                    $Online.Warning.Add([WarningType]::DuplicateNetworkObject, "$($Online.Type):$($Online.Identifier) exists in other rows 134")
                }
                return $Online
            }
            $OnlineChanged = $true
        }
        $New = [E911NetworkObject]::new($obj, $ShouldValidate)
        if ($dup) {
            $New.Warning.Add([WarningType]::DuplicateNetworkObject, "$($New.Type):$($New.Identifier) exists in other rows 142")
        }
        if (!$dup <#-and $New.Type -ne [NetworkObjectType]::Unknown#> -and ((!$New._isOnline -and $ShouldValidate) -or $OnlineChanged)) {
            if ($New.Type -ne [NetworkObjectType]::Unknown) {
                $New._hasChanged = $true
            }
            if (![E911ModuleState]::NetworkObjects.ContainsKey($New.GetHash())) {
                [E911ModuleState]::NetworkObjects.Add($New.GetHash(), $New)
            }
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
    static hidden [bool] $ShouldClearLIS = $true

    static [void] FlushCaches([PSFunctionHost] $ParentProcessHelper) {
        $flushProcess = [PSFunctionHost]::StartNew($ParentProcessHelper, 'Clearing Caches')
        try {
            [E911ModuleState]::AddressValidator.MapsQueryCount = 0
            $flushProcess.WriteVerbose('Flushing Caches...')
            $OnlineAddrCount = [E911ModuleState]::OnlineAddresses.Count
            $AddrCount = [E911ModuleState]::Addresses.Count
            $OnlineLocCount = [E911ModuleState]::OnlineLocations.Count
            $LocCount = [E911ModuleState]::Locations.Count
            $OnlineNobjCount = [E911ModuleState]::OnlineNetworkObjects.Count
            $NobjCount = [E911ModuleState]::NetworkObjects.Count
            [E911ModuleState]::OnlineAddresses.Clear()
            $flushProcess.WriteVerbose(('{0} Online Addresses Removed' -f ($OnlineAddrCount - [E911ModuleState]::OnlineAddresses.Count)))
            [E911ModuleState]::Addresses.Clear()
            $flushProcess.WriteVerbose(('{0} Addresses Removed' -f ($AddrCount - [E911ModuleState]::Addresses.Count)))
            [E911ModuleState]::OnlineLocations.Clear()
            $flushProcess.WriteVerbose(('{0} Online Locations Removed' -f ($OnlineLocCount - [E911ModuleState]::OnlineLocations.Count)))
            [E911ModuleState]::Locations.Clear()
            $flushProcess.WriteVerbose(('{0} Locations Removed' -f ($LocCount - [E911ModuleState]::Locations.Count)))
            [E911ModuleState]::OnlineNetworkObjects.Clear()
            $flushProcess.WriteVerbose(('{0} Online Network Objects Removed' -f ($OnlineNobjCount - [E911ModuleState]::OnlineNetworkObjects.Count)))
            [E911ModuleState]::NetworkObjects.Clear()
            $flushProcess.WriteVerbose(('{0} Network Objects Removed' -f ($NobjCount - [E911ModuleState]::NetworkObjects.Count)))
            [E911ModuleState]::ShouldClear = $false
        }
        finally {
            if ($null -ne $flushProcess) {
                $flushProcess.Dispose()
            }
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

    hidden static [long] $Interval = 200

    static [void] InitializeCaches([PSFunctionHost] $parent) {
        $currentProcess = [PSFunctionHost]::StartNew($parent, 'Initializing Caches')
        
        try {
            if ([E911ModuleState]::ShouldClear) {
                [E911ModuleState]::FlushCaches($currentProcess)
            }
            # Ensure all commands are re-generated on a new run
            foreach ($address in [E911ModuleState]::Addresses.Values) {
                $address._commandGenerated = $false
            }
            foreach ($address in [E911ModuleState]::OnlineAddresses.Values) {
                $address._commandGenerated = $false
            }
            foreach ($location in [E911ModuleState]::Locations.Values) {
                $location._commandGenerated = $false
            }
            foreach ($location in [E911ModuleState]::OnlineLocations.Values) {
                $location._commandGenerated = $false
            }
            foreach ($networkObject in [E911ModuleState]::NetworkObjects.Values) {
                $networkObject._commandGenerated = $false
            }
            foreach ($networkObject in [E911ModuleState]::OnlineNetworkObjects.Values) {
                $networkObject._commandGenerated = $false
            }

            if (([E911ModuleState]::Addresses.Count + [E911ModuleState]::Locations.Count + [E911ModuleState]::NetworkObjects.Count + [E911ModuleState]::OnlineAddresses.Count + [E911ModuleState]::OnlineLocations.Count + [E911ModuleState]::OnlineNetworkObjects.Count) -gt 0) {
                $currentProcess.Complete()
                return
            }

            $currentProcess.WriteVerbose('Populating Caches...')
            $currentProcess.ForceUpdate('Getting Objects from LIS')
            [LisObjectHelper]::LoadCache($currentProcess, [E911ModuleState]::ShouldClearLIS)

            $CachedAddresses = 0
            $CachedLocations = 0
            $CachedNetworkObjects = 0
            $currentProcess.WriteVerbose('Checking for Online Civic Addresses...')
            $currentProcess.ForceUpdate('Checking for Duplicate Online Civic Addresses')
            $lisCivicAddresses = [LisCivicAddress]::GetAll()
            $civicAddressSet = [LisAddressBasePrioritySet]::new($lisCivicAddresses,$currentProcess)
            if ($lisCivicAddresses.Count -gt $civicAddressSet.Count) {
                $dupNum = $lisCivicAddresses.Count - $civicAddressSet.Count
                foreach ($duplicate in $lisCivicAddresses.Where({ !$civicAddressSet.Contains($_) }) ) {
                    $newAddress = $civicAddressSet.GetDuplicate($duplicate)
                    if (!$newAddress.IsValid()) {
                        $currentProcess.WriteWarning(('Address: {0} is invalid!' -f $newAddress.CivicAddressId))
                        $dupNum--
                        continue
                    }
                    $existing = $null
                    if (![E911ModuleState]::OnlineAddresses.TryGetValue($newAddress.CivicAddressId, [ref]$existing)) {
                        $currentProcess.WriteVerbose(('Caching Address: {0}' -f $newAddress.CivicAddressId))
                        $newAddrObj = $newAddress._getE911Address()
                        [E911ModuleState]::OnlineAddresses.Add($newAddress.CivicAddressId, $newAddrObj)
                        if (![E911ModuleState]::OnlineAddresses.ContainsKey($newAddrObj.GetHash())) {
                            [E911ModuleState]::OnlineAddresses.Add($newAddrObj.GetHash(), $newAddrObj)
                            $CachedAddresses++
                        }
                        $existing = $newAddrObj
                    }
                    [E911ModuleState]::OnlineAddresses.Add($duplicate.CivicAddressId, $existing)
                    $currentProcess.WriteWarning(('Duplicate Civic Address {0}: Updating to {1}' -f $duplicate.CivicAddressId, $newAddress.CivicAddressId))
                }
                $currentProcess.WriteWarning(('Found {0} Duplicate Civic Address(es) Online' -f $dupNum))
            }
            $currentProcess.WriteVerbose('Checking for Duplicate Online Locations...')
            $currentProcess.ForceUpdate('Checking for Duplicate Online Locations')
            $lisLocations = [LisLocation]::GetAll()
            $locationSet = [LisAddressBasePrioritySet]::new($lisLocations,$currentProcess)
            if ($lisLocations.Count -gt $locationSet.Count) {
                $dupNum = ($lisLocations.Count - $locationSet.Count)
                foreach ($duplicate in $lisLocations.Where({ !$locationSet.Contains($_) }) ) {
                    $addr = $duplicate.GetCivicAddress()
                    if ($null -ne $addr -and $addr.GetDefaultLocation() -eq $duplicate -and !$civicAddressSet.Contains($addr)) {
                        $dupNum--
                        continue
                    }
                    $newLocation = $locationSet.GetDuplicate($duplicate)
                    if (!$newLocation.IsValid()) {
                        $currentProcess.WriteWarning(('Location: {0} is invalid!' -f $newLocation.LocationId))
                        continue
                    }
                    $existing = $null
                    if (![E911ModuleState]::OnlineLocations.TryGetValue($newLocation.LocationId, [ref]$existing)) {
                        $address = $null
                        if (![E911ModuleState]::OnlineAddresses.TryGetValue($newLocation.CivicAddressId, [ref] $address)) {
                            $onlineAddress = $newLocation.GetCivicAddress()
                            if (!$onlineAddress.IsValid()) {
                                $currentProcess.WriteWarning(('Address: {0} is invalid!' -f $onlineAddress.CivicAddressId))
                                continue
                            }
                            if ($null -ne $onlineAddress) {
                                $address = $onlineAddress._getE911Address()
                                [E911ModuleState]::OnlineAddresses.Add($newLocation.CivicAddressId, $address)
                                if (![E911ModuleState]::OnlineAddresses.ContainsKey($address.GetHash())) {
                                    [E911ModuleState]::OnlineAddresses.Add($address.GetHash(), $address)
                                    $CachedAddresses++
                                }
                            }
                        }
                        if ($null -eq $address) {
                            $currentProcess.WriteWarning(('Location: {0} is orphaned!' -f $newLocation.LocationId))
                            continue
                        }
                        $currentProcess.WriteVerbose(('Caching Location: {0}' -f $newLocation.LocationId))
                        $newOLoc = $newLocation._getE911Location($address)
                        if ($null -ne $address -and $newLocation.CivicAddressId -ne $address.Id.ToString()) {
                            $newOLoc._hasChanged = $true
                        }
                        [E911ModuleState]::OnlineLocations.Add($newLocation.LocationId, $newOLoc)
                        [E911ModuleState]::OnlineLocations.Add($newOLoc.GetHash(), $newOLoc)
                        $CachedLocations++
                        $existing = $newOLoc
                    }
                    [E911ModuleState]::OnlineLocations.Add($duplicate.LocationId, $existing)
                    $currentProcess.WriteWarning(('Duplicate Location {0}: Updating to {1}' -f $duplicate.LocationId, $newLocation.LocationId))
                }
            }

            $onlineLisNetworkObjects = [LisNetworkObject]::GetAll({ $true })

            $locationProcess = [PSFunctionHost]::StartNew($currentProcess, 'Caching Locations')
            $locationProcess.Total = $locationSet.Count
            foreach ($onlineLocation in $locationSet) {
                $currentProcess.Update(('Addresses: {0} Locations: {1} NetworkObjects: {2}' -f $CachedAddresses, $CachedLocations, $CachedNetworkObjects))
                $locationProcess.Update($true, ('Processing Location: {0}' -f $onlineLocation.LocationId))
                if (!$onlineLocation.IsValid()) {
                    $locationProcess.WriteWarning(('Location: {0} is invalid!' -f $onlineLocation.LocationId))
                    continue
                }
                if ([E911ModuleState]::OnlineLocations.ContainsKey($onlineLocation.LocationId)) {
                    continue
                }

                $address = $null
                if (![E911ModuleState]::OnlineAddresses.TryGetValue($onlineLocation.CivicAddressId, [ref] $address)) {
                    $onlineAddress = $onlineLocation.GetCivicAddress()
                    if (!$onlineAddress.IsValid()) {
                        $locationProcess.WriteWarning(('Address: {0} is invalid!' -f $onlineAddress.CivicAddressId))
                        continue
                    }
                    if ($null -ne $onlineAddress) {
                        $locationProcess.WriteVerbose(('Caching Address: {0}' -f $onlineAddress.CivicAddressId))
                        $address = $onlineAddress._getE911Address()
                        [E911ModuleState]::OnlineAddresses.Add($onlineAddress.CivicAddressId, $address)
                        if (![E911ModuleState]::OnlineAddresses.ContainsKey($address.GetHash())) {
                            [E911ModuleState]::OnlineAddresses.Add($address.GetHash(), $address)
                            $CachedAddresses++
                        }
                    }
                }
                if ($null -eq $address) {
                    $locationProcess.WriteWarning(('Location: {0} is orphaned!' -f $onlineLocation.LocationId))
                    continue
                }
                $locationProcess.WriteVerbose(('Caching Location: {0}' -f $onlineLocation.LocationId))
                $newOLoc = $onlineLocation._getE911Location($address)
                if ($null -ne $address -and $onlineLocation.CivicAddressId -ne $address.Id.ToString()) {
                    $newOLoc._hasChanged = $true
                }
                [E911ModuleState]::OnlineLocations.Add($onlineLocation.LocationId, $newOLoc)
                [E911ModuleState]::OnlineLocations.Add($newOLoc.GetHash(), $newOLoc)
                $CachedLocations++
            }
            $locationProcess.Complete()
            $currentProcess.WriteVerbose(('Cached {0} Civic Addresses' -f $CachedAddresses))
            $currentProcess.WriteVerbose(('Cached {0} Locations' -f $CachedLocations))

            $networkObjectProcess = [PSFunctionHost]::StartNew($currentProcess, 'Caching Network Objects')
            $networkObjectProcess.Total = $onlineLisNetworkObjects.Count
            foreach ($networkObject in $onlineLisNetworkObjects) {
                $networkObjectProcess.WriteVerbose(('Processing {0}: {1}' -f $networkObject.Type, $networkObject.Identifier()))
                $currentProcess.Update(('Addresses: {0} Locations: {1} NetworkObjects: {2}' -f $CachedAddresses, $CachedLocations, $CachedNetworkObjects))
                $networkObjectProcess.Update($true, ('Processing {0}: {1}' -f $networkObject.Type, $networkObject.Identifier()))
                $newLocation = $null
                if (![E911ModuleState]::OnlineLocations.TryGetValue($networkObject.LocationId, [ref] $newLocation)) {
                    $networkObjectProcess.WriteWarning(('{0}: {1} is orphaned!' -f $networkObject.Type, $networkObject.Identifier()))
                    continue
                }
                $newNetworkObject = [E911NetworkObject]::new($true, @{
                        Type        = $networkObject.Type
                        Identifier  = $networkObject.Identifier()
                        Description = if ($null -eq $networkObject.Description) { '' } else { $networkObject.Description }
                    })
                $newNetworkObject._location = $newLocation
                $newNetworkObject._hasChanged = $networkObject.LocationId -ne $newLocation.Id.ToString() -or $newLocation._hasChanged
                [E911ModuleState]::OnlineNetworkObjects.Add($newNetworkObject.GetHash(), $newNetworkObject)
                $CachedNetworkObjects++
            }
            $currentProcess.WriteVerbose(('Cached {0} Network Objects' -f $CachedNetworkObjects))
        }
        finally {
            if ($null -ne $currentProcess) {
                $currentProcess.Dispose()
            }
        }
    }
}
