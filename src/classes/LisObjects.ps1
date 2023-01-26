using namespace System.Collections.Generic
using namespace System.Management.Automation
using namespace System.Reflection
using namespace System.Text

class CachedLisObject {
    [DateTime] $CacheInsertionTime
    [LisObject] $WrappedObject
    CachedLisObject() {}
    CachedLisObject([LisObject] $obj) {
        $TypeInfo = $obj.GetType()
        $this.CacheInsertionTime = [DateTime]::Now
        $this.WrappedObject = $obj
        $cache = [LisCache]::Cache[$TypeInfo]
        if ($null -eq $cache) {
            [LisCache]::Cache[$TypeInfo] = @{}
            $cache = [LisCache]::Cache[$TypeInfo]
        }
        $cache[$this.WrappedObject.Identifier()] = $this
    }
    static [void] CacheObject([LisObject] $obj) {
        [CachedLisObject]::new($obj)
    }
    static [LisObject] GetFromCache([Type] $TypeInfo, [string] $identifier, [bool] $ForceUpdate) {
        $Cache = [LisCache]::Cache[$TypeInfo]
        $Result = $null
        if ($null -ne $Cache -and $Cache.TryGetValue($identifier, [ref]$Result) -and $Result.CacheInsertionTime -gt [DateTime]::Now.AddMinutes(-[LisCache]::CacheLifetime)) {
            if ($ForceUpdate) {
                $Cache.Remove($identifier)
                return $null
            }
            return $Result.WrappedObject
        }
        return $null
    }
    static [List[LisObject]] GetAllFromCache([Type] $TypeInfo, [bool] $ForceUpdate) {
        $Cache = [LisCache]::Cache[$TypeInfo]
        $LastForcedRefresh = [LisCache]::LastForcedRefresh[$TypeInfo]
        if (($null -eq $LastForcedRefresh -or ($LastForcedRefresh - [DateTime]::Now).TotalSeconds -gt 30) -and $ForceUpdate -and $null -ne $Cache) {
            $Cache.Clear()
            $Cache = $null
        }
        if ($null -ne $Cache) {
            $Expired = $Cache.Values.Where({ $_.CacheInsertionTime -lt [DateTime]::Now.AddMinutes(-[LisCache]::CacheLifetime) })
            $Values = $Cache.Values.ForEach({ $_.WrappedObject })
            if ($Expired.Count -eq 0 -and $Values.Count -gt 0) {
                if ($ForceUpdate) {
                    # trying to prevent too many full refreshes when we don't really need them
                    [LisCache]::LastForcedRefresh[$TypeInfo] = [DateTime]::Now
                }
                return [LisObject[]]$Values
            }
            $Cache.Clear()
        }
        return $null
    }
    static [bool] IsMissing([Type] $TypeInfo, [string] $identifier, [bool] $ForceUpdate) {
        $Missing = [LisCache]::Missing[$TypeInfo]
        if ($null -eq $Missing) {
            [LisCache]::Missing[$TypeInfo] = @()
            $Missing = [LisCache]::Missing[$TypeInfo]
        }
        if ($ForceUpdate) {
            $Missing.Remove($identifier)
            return $false
        }
        return $Missing.Contains($identifier)
    }

    static [void] AddMissing([Type] $TypeInfo, [string] $identifier) {
        $Missing = [LisCache]::Missing[$TypeInfo]
        if ($null -eq $Missing) {
            [LisCache]::Missing[$TypeInfo] = @()
            $Missing = [LisCache]::Missing[$TypeInfo]
        }
        $Missing.Add($identifier)
    }
}

class LisCache {
    static [Dictionary[Type, Dictionary[string, CachedLisObject]]] $Cache = @{}
    static [Dictionary[Type, DateTime]] $LastForcedRefresh = @{}
    static [Dictionary[Type, HashSet[string]]] $Missing = @{}
    static [int] $CacheLifetime = 480
    static [void] Clear() {
        [LisCache]::Cache.Clear()
    }
}

class LisObject {
    LisObject() {}
    LisObject([object] $obj) {
        $Properties = [LisObject]::_getPublicPwshClassProperties($this.GetType()).Name
        foreach ($Prop in $Properties) {
            $this.$Prop = $obj.$Prop
        }
        [CachedLisObject]::CacheObject($this)
    }
    [string] Identifier() { return $this.GetType().Name }
    static [hashtable] IdentifierParams([string] $identifier) { return @{} }
    hidden static [List[LisObject]] _getAll([Type] $type, [CommandInfo] $command, [bool] $ForceUpdate) {
        return [LisObject]::_get($type, $command, '', @{}, $ForceUpdate)
    }
    hidden static [List[LisObject]] _get([Type] $type, [CommandInfo] $command, [string] $identifier, [hashtable] $additionalParams, [bool] $ForceUpdate) {
        $params = @{ ErrorAction = 'Stop' }
        foreach ($key in $additionalParams.Keys) {
            $params[$key] = $additionalParams[$key]
        }
        $PointQuery = ![string]::IsNullOrEmpty($identifier)
        if ($PointQuery) {
            if ([CachedLisObject]::IsMissing($type, $identifier, $ForceUpdate)) { return @() }
            # if ($additionalParams.Keys.Count -eq 0) {
                $Result = [CachedLisObject]::GetFromCache($type, $identifier, $ForceUpdate)
                if ($null -ne $Result -and !$ForceUpdate) { return [LisObject[]]@($Result) }
            # }
            $idParams = $type::IdentifierParams($identifier)
            foreach ($key in $idParams.Keys) {
                $params[$key] = $idParams[$key]
            }
        }
        else {
            $Result = [CachedLisObject]::GetAllFromCache($type, $ForceUpdate)
            if ($null -ne $Result) { return [LisObject[]]$Result }
        }
        try {
            $LisObjects = [LisObject[]]({ & $command @params }.Invoke().ForEach({ $_ -as $type }))
            if ($PointQuery -and $null -eq $LisObjects[0]) {
                [CachedLisObject]::AddMissing($type, $identifier)
                return @()
            }
            return $LisObjects
        }
        catch {
            Write-Warning $_.Exception.Message
        }
        return @()
    }
    [bool] PossibleDuplicate([object] $obj) {
        if ($null -eq $obj) { return $false }
        if ($this.GetType() -ne $obj.GetType()) { return $false }
        $lObj = $obj -as ($this.GetType())
        if ($this.GetHash() -ne $lObj.GetHash()) { return $false }
        return $true
    }
    [bool] ValueEquals([object] $obj) {
        if(!$this.PossibleDuplicate($obj)) { return $false }
        $lObj = $obj -as ($this.GetType())
        $Properties = [LisObject]::_getPublicPwshClassProperties($this.GetType()).Name
        foreach ($Prop in $Properties) {
            if ($this.$Prop -ne $lObj.$Prop) { return $false }
        }
        return $true
    }
    # [int] GetHashCode() {
    #     return $this.GetHash().GetHashCode()
    # }
    hidden static [PropertyInfo[]] _getPublicPwshClassProperties([Type] $type) {
        return [PropertyInfo[]]$type.GetProperties('Instance,Public').Where({
            $_.CustomAttributes.Where({$_.AttributeType -eq [HiddenAttribute]},'First',1).Count -eq 0})
    }
    [string] ToString() {
        return $this.Identifier()
    }
}

class LisNetworkObject : LisObject {
    [Guid] $LocationId
    [string] $Description
    [string] $Type
    LisNetworkObject() {
        $this.Type = $this.GetType().Name -replace '^Lis', ''
    }
    LisNetworkObject([object] $obj) : base($obj) {
        $TypeInfo = $this.GetType()
        $this.Type = $TypeInfo.Name -replace '^Lis', ''
    }
    hidden [bool] $_orphanedCheckDone = $false
    hidden [bool] $_isOrphaned
    [bool] IsOrphaned() {
        return $this.IsOrphaned($false)
    }
    [bool] IsOrphaned([bool] $ForceUpdate) {
        if (!$this._orphanedCheckDone -or $ForceUpdate) {
            $location = $this.GetLocation($ForceUpdate)
            $this._isOrphaned = $null -eq $location -or $location.IsOrphaned($ForceUpdate)
        }
        return $this._isOrphaned
    }
    static [List[LisNetworkObject]] GetAll() {
        return [LisNetworkObject]::GetAll($false, $false, { $true })
    }
    static [List[LisNetworkObject]] GetAll([bool] $ForceUpdate) {
        return [LisNetworkObject]::GetAll($false, $ForceUpdate, { $true })
    }
    static [List[LisNetworkObject]] GetAll([bool] $IncludeOrphaned, [bool] $ForceUpdate) {
        return [LisNetworkObject]::GetAll($IncludeOrphaned, $ForceUpdate, { $true })
    }
    static [List[LisNetworkObject]] GetAll([Func[LisNetworkObject, bool]] $Filter) {
        return [LisNetworkObject]::GetAll($false, $false, $Filter)
    }
    static [List[LisNetworkObject]] GetAll([bool] $ForceUpdate, [Func[LisNetworkObject, bool]] $Filter) {
        return [LisNetworkObject]::GetAll($false, $ForceUpdate, $Filter)
    }
    static [List[LisNetworkObject]] GetAll([bool] $IncludeOrphaned, [bool] $ForceUpdate, [Func[LisNetworkObject, bool]] $Filter) {
        $result = [List[LisNetworkObject]]@()
        $result.AddRange([LisPort[]][LisPort]::GetAll($ForceUpdate).Where({$Filter.Invoke($_)}).Where({ $IncludeOrphaned -or !$_.IsOrphaned() }))
        $result.AddRange([LisSwitch[]][LisSwitch]::GetAll($ForceUpdate).Where({$Filter.Invoke($_)}).Where({ $IncludeOrphaned -or !$_.IsOrphaned() }))
        $result.AddRange([LisSubnet[]][LisSubnet]::GetAll($ForceUpdate).Where({$Filter.Invoke($_)}).Where({ $IncludeOrphaned -or !$_.IsOrphaned() }))
        $result.AddRange([LisWirelessAccessPoint[]][LisWirelessAccessPoint]::GetAll($ForceUpdate).Where({$Filter.Invoke($_)}).Where({ $IncludeOrphaned -or !$_.IsOrphaned() }))
        return $result
    }
    hidden [LisLocation] $_location = $null
    [LisLocation] GetLocation() {
        return $this.GetLocation($false)
    }
    [LisLocation] GetLocation([bool] $ForceUpdate) {
        if ($null -eq $this._location -or $ForceUpdate) {
            $this._location = [LisLocation]::GetById($this.LocationId, $ForceUpdate)
        }
        return $this._location
    }
    hidden [LisCivicAddress] $_civicAddress = $null
    [LisCivicAddress] GetCivicAddress() {
        return $this.GetCivicAddress($false)
    }
    [LisCivicAddress] GetCivicAddress([bool] $ForceUpdate) {
        if ($null -eq $this._civicAddress -or $ForceUpdate) {
            $location = $this.GetLocation($ForceUpdate)
            $this._civicAddress = [LisCivicAddress]::GetById($location.CivicAddressId, $ForceUpdate)
        }
        return $this._civicAddress
    }
}

class LisAddressBase : LisObject {
    [Guid] $CivicAddressId
    [string] $CompanyName
    [string] $CompanyTaxId
    [string] $HouseNumber
    [string] $HouseNumberSuffix
    [string] $PreDirectional
    [string] $StreetName
    [string] $StreetSuffix
    [string] $PostDirectional
    [string] $City
    [string] $PostalCode
    [string] $StateOrProvince
    [string] $CountryOrRegion
    [string] $Description
    [string] $Latitude
    [string] $Longitude
    [string] $Elin
    [int] $NumberOfVoiceUsers
    [int] $NumberOfTelephoneNumbers
    hidden [bool] $_validDone = $false
    hidden [bool] $_isValid
    hidden [bool] $_useCheckDone = $false
    hidden [bool] $_isInUse
    LisAddressBase() {}
    LisAddressBase([object] $obj) : base($obj) {}
    [CommandInfo] GetItemCommand() { throw 'Not implemented' }
    [bool] IsInUse() {
        return $this.IsInUse($false)
    }
    [bool] IsInUse([bool] $ForceUpdate) {
        if (!$this._useCheckDone -or $ForceUpdate) {
            if ($this.NumberOfTelephoneNumbers -eq -1 -or $this.NumberOfVoiceUsers -eq -1 -or $ForceUpdate) {
                $WithInfo = [LisAddressBase]::_get($this.Identifier(), $this.GetItemCommand(), $this.GetType(), $ForceUpdate)
                $this.NumberOfTelephoneNumbers = $WithInfo.NumberOfTelephoneNumbers
                $this.NumberOfVoiceUsers = $WithInfo.NumberOfVoiceUsers
            }
            $this._isInUse = $this.NumberOfTelephoneNumbers -gt 0 -or $this.NumberOfVoiceUsers -gt 0
            if (!$this._isInUse) {
                $this._isInUse = $this.GetAssociatedNetworkObjects($ForceUpdate).Count -gt 0
            }
            $this._useCheckDone = $true
        }
        return $this._isInUse
    }
    hidden [List[LisNetworkObject]] $_associatedNetworkObjects = $null
    [bool] IsValid() { return $this.IsValid($false) }
    [bool] IsValid([bool] $ForceUpdate) { return $true }
    hidden static [List[LisAddressBase]] _get([string] $identifier, [CommandInfo] $command, [Type] $type, [bool] $ForceUpdate) {
        $additionalParams = @{
            PopulateNumberOfTelephoneNumbers = $true
            PopulateNumberOfVoiceUsers = $true
        }
        return [LisAddressBase[]][LisObject]::_get($type, $command, $identifier, $additionalParams, $ForceUpdate)
    }

    [List[LisNetworkObject]] GetAssociatedNetworkObjects() { return $this.GetAssociatedNetworkObjects($false) }
    [List[LisNetworkObject]] GetAssociatedNetworkObjects([bool] $ForceUpdate) { throw 'Must Override Base Method' }

    static [string] ConvertAddressPartsToAddress([LisAddressBase] $address) {
        $addressSb = [StringBuilder]::new()
        $addressSb.AppendJoin(' ', $address.HouseNumber, $address.HouseNumberSuffix, $address.PreDirectional, $address.StreetName, $address.StreetSuffix, $address.PostDirectional)
        do {
            # remove all double spaces until there are no more
            $len = $addressSb.Length
            $addressSb.Replace('  ', ' ')
        } while ($addressSb.Length -lt $len)
        return $addressSb.ToString().Trim()
    }

    [int] CompareTo([object] $obj) {
        if ($null -eq $obj) { return 1 }
        $loc = $obj -as [LisLocation]
        if ($loc -eq $this) { return 0 }
        if ($loc.StateOrProvince -ne $this.StateOrProvince) {
            return [string]::Compare($this.StateOrProvince, $loc.StateOrProvince, $true)
        }
        if ($loc.City -ne $this.City) {
            return [string]::Compare($this.City, $loc.City, $true)
        }
        if ($loc.PostalCode -ne $this.PostalCode) {
            return [string]::Compare($this.PostalCode, $loc.PostalCode, $true)
        }
        $locAddress = [LisAddressBase]::ConvertAddressPartsToAddress($loc)
        $thisAddress = [LisAddressBase]::ConvertAddressPartsToAddress($this)
        return [string]::Compare($thisAddress, $locAddress, $true)
    }
}

class LisLocation : LisAddressBase {
    hidden static [CommandInfo] $_getItemCommand = $null
    [Guid] $LocationId
    [string] $Location
    LisLocation() {}
    LisLocation([object] $obj) : base($obj) {}
    [string] Identifier() {
        return $this.LocationId.ToString()
    }
    static [hashtable] IdentifierParams([string] $identifier) {
        return @{ LocationId = $identifier }
    }
    [CommandInfo] GetItemCommand() {
        return [LisLocation]::GetItemCommandStatic()
    }
    static [CommandInfo] GetItemCommandStatic() {
        if ($null -eq [LisLocation]::_getItemCommand) {
            [LisLocation]::_getItemCommand = Get-Command -Name Get-CsOnlineLisLocation
        }
        return [LisLocation]::_getItemCommand
    }
    hidden [bool] $_orphanedCheckDone = $false
    hidden [bool] $_isOrphaned
    [bool] IsValid([bool] $ForceUpdate) {
        if (!$this._validDone -or $ForceUpdate) {
            $address = $this.GetCivicAddress($ForceUpdate)
            $this._isValid = !$this.IsOrphaned($ForceUpdate) -and $address.IsValid($ForceUpdate)
            if ($this.LocationId -eq $address.DefaultLocationId) {
                $PropertiesToCheck = @(
                    'CompanyName'
                    'CompanyTaxId'
                    'HouseNumber'
                    'HouseNumberSuffix'
                    'PreDirectional'
                    'StreetName'
                    'StreetSuffix'
                    'PostDirectional'
                    'City'
                    'PostalCode'
                    'StateOrProvince'
                    'CountryOrRegion'
                    'Latitude'
                    'Longitude'
                    'Elin'
                )
                foreach ($Prop in $PropertiesToCheck) {
                    $this._isValid = $address.$Prop -eq $this.$Prop
                    if (!$this._isValid) {
                        $address._isValid = $false
                        $address._validDone = $true
                        break
                    }
                }
            }
            $this._validDone = $true
        }
        return $this._isValid
    }
    [bool] IsOrphaned() {
        return $this.IsOrphaned($false)
    }
    [bool] IsOrphaned([bool] $ForceUpdate) {
        if (!$this._orphanedCheckDone -or $ForceUpdate) {
            $address = $this.GetCivicAddress($ForceUpdate)
            $this._isOrphaned = $null -eq $address
        }
        return $this._isOrphaned
    }
    static [LisLocation] GetById([string] $LocationId) {
        return [LisLocation]::GetById($LocationId, $false)
    }
    static [LisLocation] GetById([string] $LocationId, [bool] $ForceUpdate) {
        return [LisLocation]::Get($LocationId, $ForceUpdate)[0]
    }
    static [List[LisLocation]] GetAll() {
        return [LisLocation]::GetAll($false)
    }
    static [List[LisLocation]] GetAll([bool] $ForceUpdate) {
        return [LisLocation]::Get('', $ForceUpdate)
    }
    static [List[LisLocation]] GetAll([Func[LisLocation,bool]] $Filter) {
        return [LisLocation]::GetAll($false, $Filter)
    }
    static [List[LisLocation]] GetAll([bool] $ForceUpdate, [Func[LisLocation,bool]] $Filter) {
        return [LisLocation[]][LisLocation]::Get('', $ForceUpdate).Where({ $Filter.Invoke($_) })
    }
    static [List[LisLocation]] Get([string] $LocationId, [bool] $ForceUpdate) {
        return [LisLocation[]][LisAddressBase]::_get($LocationId, [LisLocation]::GetItemCommandStatic(), [LisLocation], $ForceUpdate)
    }
    [List[LisNetworkObject]] GetAssociatedNetworkObjects([bool] $ForceUpdate) {
        if ($null -eq $this._associatedNetworkObjects -or $ForceUpdate) {
            $this._associatedNetworkObjects = [LisNetworkObject[]][LisNetworkObject]::GetAll($ForceUpdate, [Func[LisNetworkObject,bool]]{ $args[0].LocationId -eq $this.LocationId })
            $address = $this.GetCivicAddress($ForceUpdate)
            foreach ($no in $this._associatedNetworkObjects) {
                $no._location = $this
                $no._civicAddress = $address
            }
        }
        return $this._associatedNetworkObjects
    }
    hidden [string] $_hash
    [string] GetHash() {
        if ([string]::IsNullOrEmpty($this._hash)) {
            $this._hash = [E911Location]::GetHash($this)
        }
        return $this._hash
    }

    hidden [LisCivicAddress] $_civicAddress = $null
    [LisCivicAddress] GetCivicAddress() {
        return $this.GetCivicAddress($false)
    }
    [LisCivicAddress] GetCivicAddress([bool] $ForceUpdate) {
        if ($null -eq $this._civicAddress -or $ForceUpdate) {
            $this._civicAddress = [LisCivicAddress]::GetById($this.CivicAddressId, $ForceUpdate)
        }
        return $this._civicAddress
    }

    hidden [E911Location] _getE911Location([E911Address] $address) {
        $hash = @{
            Location   = if ([string]::IsNullOrEmpty($this.Location)) { '' } else { $this.Location }
            Elin       = if ([string]::IsNullOrEmpty($this.Elin)) { '' } else { $this.Elin }
            Id         = [ItemId]::new($this.LocationId)
            _address   = $address
            _isDefault = [string]::IsNullOrEmpty($this.Location)
        }
        $newOLoc = [E911Location]::new($true)
        foreach ($key in $hash.Keys) {
            $newOLoc.$key = $hash[$key]
        }
        return $newOLoc
    }

    [int] CompareTo([object] $obj) {
        $baseResult = ([LisAddressBase]$this).CompareTo($obj)
        if ($baseResult -ne 0) {
            return $baseResult
        }
        $loc = $obj -as [LisLocation]
        if ($loc.Location -ne $this.Location) {
            return [string]::Compare($this.Location, $loc.Location, $true)
        }
        return [string]::Compare($this.LocationId, $loc.LocationId, $true)
    }

    [int] ComparePriorityTo([LisLocation] $obj) {
        if ($this.GetHash() -ne $obj.GetHash()) {
            return $this.CompareTo($obj)
        }
        $loc = $obj -as [LisLocation]
        $result = [LisLocation]::GetBestLocation($this, $obj)
        if ($result -eq $this) { return -1 }
        if ($result -eq $loc) { return 1 }
        return 0
    }

    hidden static [Func[LisLocation,LisLocation,LisLocation][]] $_locationPriorityTests = @(
        {
            param($l1,$l2)
            $l1TestSuccessful = $l1.IsOrphaned()
            $l2TestSuccessful = $l2.IsOrphaned()
            if ($l1TestSuccessful -and !$l2TestSuccessful) { return $l1 }
            if ($l2TestSuccessful -and !$l1TestSuccessful) { return $l2 }
            return $null
        }
        {
            param($l1,$l2)
            $l1TestSuccessful = $l1.IsValid()
            $l2TestSuccessful = $l2.IsValid()
            if ($l1TestSuccessful -and !$l2TestSuccessful) { return $l1 }
            if ($l2TestSuccessful -and !$l1TestSuccessful) { return $l2 }
            return $null
        }
        {
            param($l1,$l2)
            $l1TestSuccessful = ($l1.Longitude -replace '0','').Length -gt 1 -and ($l1.Latitude -replace '0','').Length -gt 1
            $l2TestSuccessful = ($l2.Longitude -replace '0','').Length -gt 1 -and ($l2.Latitude -replace '0','').Length -gt 1
            if ($l1TestSuccessful -and !$l2TestSuccessful) { return $l1 }
            if ($l2TestSuccessful -and !$l1TestSuccessful) { return $l2 }
            return $null
        }
        {
            param($l1,$l2)
            $l1TestSuccessful = $l1.IsInUse()
            $l2TestSuccessful = $l2.IsInUse()
            if ($l1TestSuccessful -and !$l2TestSuccessful) { return $l1 }
            if ($l2TestSuccessful -and !$l1TestSuccessful) { return $l2 }
            return $null
        }
        {
            param($l1,$l2)
            $a1 = $l1.GetAddress()
            $a2 = $l2.GetAddress()
            $l1TestSuccessful = $a1.IsInUse()
            $l2TestSuccessful = $a2.IsInUse()
            if ($l1TestSuccessful -and !$l2TestSuccessful) { return $l1 }
            if ($l2TestSuccessful -and !$l1TestSuccessful) { return $l2 }
            return $null
        }
        {
            param($l1,$l2)
            $a1 = $l1.GetAddress()
            $a2 = $l2.GetAddress()
            $a1Count = $a1.GetAssociatedNetworkObjects().Count
            $a2Count = $a2.GetAssociatedNetworkObjects().Count
            if ($a1Count -gt $a2Count) { return $l1 }
            if ($a2Count -gt $a1Count) { return $l2 }
            return $null
        }
        {
            param($l1,$l2)
            $a1 = $l1.GetAddress()
            $a2 = $l2.GetAddress()
            $a1Count = $a1.NumberOfVoiceUsers + $a1.NumberOfTelephoneNumbers
            $a2Count = $a2.NumberOfVoiceUsers + $a2.NumberOfTelephoneNumbers
            if ($a1Count -gt $a2Count) { return $l1 }
            if ($a2Count -gt $a1Count) { return $l2 }
            return $null
        }
        {
            param($l1,$l2)
            $l1Count = $l1.NumberOfVoiceUsers + $l1.NumberOfTelephoneNumbers
            $l2Count = $l2.NumberOfVoiceUsers + $l2.NumberOfTelephoneNumbers
            if ($l1Count -gt $l2Count) { return $l1 }
            if ($l2Count -gt $l1Count) { return $l2 }
            return $null
        }
        {
            param($l1,$l2)
            $l1Count = $l1.GetAssociatedNetworkObjects().Count
            $l2Count = $l2.GetAssociatedNetworkObjects().Count
            if ($l1Count -gt $l2Count) { return $l1 }
            if ($l2Count -gt $l1Count) { return $l2 }
            return $null
        }
    )

    static [LisLocation] GetBestLocation([LisLocation]$location1, [LisLocation]$location2) {
        $bestLocation = $location1
        foreach ($test in [LisLocation]::_locationPriorityTests) {
            $testResult = $test.Invoke($location1, $location2)
            if ($null -ne $testResult) {
                $bestLocation = $testResult
                break
            }
        }
        return $bestLocation
    }
}

class LisCivicAddress : LisAddressBase {
    hidden static [CommandInfo] $_getItemCommand = $null
    [Guid] $DefaultLocationId
    LisCivicAddress() {}
    LisCivicAddress([object] $obj) : base($obj) {}
    [string] Identifier() {
        return $this.CivicAddressId.ToString()
    }
    static [hashtable] IdentifierParams([string] $identifier) {
        return @{ CivicAddressId = $identifier }
    }
    [CommandInfo] GetItemCommand() {
        if ($null -eq [LisCivicAddress]::_getItemCommand) {
            [LisCivicAddress]::_getItemCommand = Get-Command -Name Get-CsOnlineLisCivicAddress
        }
        return [LisCivicAddress]::_getItemCommand
    }
    [bool] IsValid([bool] $ForceUpdate) {
        if (!$this._validDone -or $ForceUpdate) {
            $location = [LisLocation]::GetById($this.DefaultLocationId, $ForceUpdate)
            $this._isValid = $null -ne $location
            if ($this._isValid) {
                $PropertiesToCheck = @(
                    'CompanyName'
                    'CompanyTaxId'
                    'HouseNumber'
                    'HouseNumberSuffix'
                    'PreDirectional'
                    'StreetName'
                    'StreetSuffix'
                    'PostDirectional'
                    'City'
                    'PostalCode'
                    'StateOrProvince'
                    'CountryOrRegion'
                    'Latitude'
                    'Longitude'
                    'Elin'
                )
                foreach ($Prop in $PropertiesToCheck) {
                    $this._isValid = $location.$Prop -eq $this.$Prop
                    if (!$this._isValid) {
                        $location._isValid = $false
                        $location._validDone = $true
                        break
                    }
                }
            }
            if (!$this._isValid) {
                $AllLocations = [LisLocation]::GetAll($ForceUpdate).Where({ $_.CivicAddressId -eq $this.CivicAddressId })
                foreach ($location in $AllLocations) {
                    $location._isValid = $false
                    $location._validDone = $true
                }
            }
            $this._validDone = $true
        }
        return $this._isValid
    }
    static [LisCivicAddress] GetById([string] $CivicAddressId) {
        return [LisCivicAddress]::GetById($CivicAddressId, $false)
    }
    static [LisCivicAddress] GetById([string] $CivicAddressId, [bool] $ForceUpdate) {
        return [LisCivicAddress]::Get($CivicAddressId, $ForceUpdate)[0]
    }
    static [List[LisCivicAddress]] GetAll() {
        return [LisCivicAddress]::GetAll($false)
    }
    static [List[LisCivicAddress]] GetAll([bool] $ForceUpdate) {
        return [LisCivicAddress]::Get('', $ForceUpdate)
    }
    static [List[LisCivicAddress]] Get([string] $CivicAddressId, [bool] $ForceUpdate) {
        if ($null -eq [LisCivicAddress]::_getItemCommand) {
            [LisCivicAddress]::_getItemCommand = Get-Command -Name Get-CsOnlineLisCivicAddress
        }
        return [LisCivicAddress[]][LisAddressBase]::_get($CivicAddressId, [LisCivicAddress]::_getItemCommand, [LisCivicAddress], $ForceUpdate)
    }
    [List[LisLocation]] GetAssociatedLocations() {
        return $this.GetAssociatedLocations($false)
    }
    hidden [List[LisLocation]] $_associatedLocations = $null
    [List[LisLocation]] GetAssociatedLocations([bool] $ForceUpdate) {
        if ($null -eq $this._associatedLocations -or $ForceUpdate) {
            $this._associatedLocations = [LisLocation[]][LisLocation]::GetAll($ForceUpdate, [Func[LisLocation,bool]]{$args[0].CivicAddressId -eq $this.CivicAddressId})
            foreach ($l in $this._associatedLocations) {
                $l._civicAddress = $this
            }
        }
        return $this._associatedLocations
    }
    [List[LisNetworkObject]] GetAssociatedNetworkObjects([bool] $ForceUpdate) {
        if ($null -eq $this._associatedNetworkObjects -or $ForceUpdate) {
            # $All = [LisNetworkObject]::GetAll($ForceUpdate)
            # $Locations = [HashSet[Guid]][Guid[]]$this.GetAssociatedLocations($ForceUpdate).LocationId
            # $this._associatedNetworkObjects =  [LisNetworkObject[]]$All.Where({ $_.LocationId -in $Locations })
            $this._associatedNetworkObjects = @()
            foreach ($location in $this.GetAssociatedLocations($ForceUpdate)) {
                $nobj = $location.GetAssociatedNetworkObjects($ForceUpdate)
                if ($null -eq $nobj) { continue }
                $this._associatedNetworkObjects.AddRange($nobj)
            }
        }
        return $this._associatedNetworkObjects
    }
    hidden [string] $_hash
    [string] GetHash() {
        if ([string]::IsNullOrEmpty($this._hash)) {
            $this._hash = [E911Address]::GetHash($this)
        }
        return $this._hash
    }
    hidden static [string[]] $_e911AddressProps = @('DefaultLocationId', 'CompanyName', 'CompanyTaxId', 'Description', 'City', 'StateOrProvince', 'PostalCode', 'CountryOrRegion', 'Latitude', 'Longitude', 'Elin')
    hidden [E911Address] _getE911Address() {
        $hash = @{}
        foreach ($p in [LisCivicAddress]::_e911AddressProps) {
            $hash[$p] = $this.$p
        }
        $hash['Id'] = [ItemId]::new($this.CivicAddressId)
        $hash['SkipMapsLookup'] = (![string]::IsNullOrEmpty($this.Latitude) -and $this.Latitude -ne '0.0') -and (![string]::IsNullOrEmpty($this.Longitude) -and $this.Longitude -ne '0.0')
        $hash['Address'] = [LisAddressBase]::ConvertAddressPartsToAddress($this)
        if ([string]::IsNullOrEmpty($hash['Elin'])) { $hash['Elin'] = '' }
        $newOAddr = [E911Address]::new($true)
        foreach ($key in $hash.Keys) {
            $newOAddr.$key = $hash[$key]
        }
        return $newOAddr
    }
}

class LisPort : LisNetworkObject {
    hidden static [CommandInfo] $_getItemCommand = $null
    [string] $ChassisId
    [string] $PortId
    LisPort() {}
    LisPort([object] $obj) : base($obj) {}
    [string] Identifier() { return $this.ChassisId + ';' + $this.PortId }
    static [hashtable] IdentifierParams([string] $identifier) { return @{ ChassisId = $identifier.Split(';')[0]; PortId = $identifier.Split(';')[1] } }
    static [List[LisPort]] GetAll() {
        return [LisPort]::GetAll($false)
    }
    static [List[LisPort]] GetAll([bool] $ForceUpdate) {
        if ($null -eq [LisPort]::_getItemCommand) {
            [LisPort]::_getItemCommand = Get-Command -Name Get-CsOnlineLisPort
        }
        return [LisPort[]][LisObject]::_getAll([LisPort], [LisPort]::_getItemCommand, $ForceUpdate)
    }
    static [LisPort] Get([string] $identifier) {
        return [LisPort]::Get($identifier, $false)
    }
    static [LisPort] Get([string] $identifier, [bool] $ForceUpdate) {
        if ($null -eq [LisPort]::_getItemCommand) {
            [LisPort]::_getItemCommand = Get-Command -Name Get-CsOnlineLisPort
        }
        return [LisPort][LisObject]::_get([LisPort], [LisPort]::_getItemCommand, $identifier, @{}, $ForceUpdate)
    }
    static [LisPort] Get([string] $ChassisID, [string] $PortId) {
        return [LisPort]::Get($ChassisID, $PortID, $false)
    }
    static [LisPort] Get([string] $ChassisID, [string] $PortId, [bool] $ForceUpdate) {
        return [LisPort]::Get($ChassisID + ';' + $PortID, $ForceUpdate)
    }
}

class LisSwitch : LisNetworkObject {
    hidden static [CommandInfo] $_getItemCommand = $null
    [string] $ChassisId
    LisSwitch() {}
    LisSwitch([object] $obj) : base($obj) {}
    [string] Identifier() { return $this.ChassisId }
    static [hashtable] IdentifierParams([string] $identifier) { return @{ ChassisId = $identifier } }
    static [List[LisSwitch]] GetAll() {
        return [LisSwitch]::GetAll($false)
    }
    static [List[LisSwitch]] GetAll([bool] $ForceUpdate) {
        if ($null -eq [LisSwitch]::_getItemCommand) {
            [LisSwitch]::_getItemCommand = Get-Command -Name Get-CsOnlineLisSwitch
        }
        return [LisSwitch[]][LisObject]::_getAll([LisSwitch], [LisSwitch]::_getItemCommand, $ForceUpdate)
    }
    static [LisSwitch] Get([string] $identifier) {
        return [LisSwitch]::Get($identifier, $false)
    }
    static [LisSwitch] Get([string] $identifier, [bool] $ForceUpdate) {
        if ($null -eq [LisSwitch]::_getItemCommand) {
            [LisSwitch]::_getItemCommand = Get-Command -Name Get-CsOnlineLisSwitch
        }
        return [LisSwitch][LisObject]::_get([LisSwitch], [LisSwitch]::_getItemCommand, $identifier, @{}, $ForceUpdate)
    }
}

class LisSubnet : LisNetworkObject {
    hidden static [CommandInfo] $_getItemCommand = $null
    [string] $Subnet
    LisSubnet() {}
    LisSubnet([object] $obj) : base($obj) {}
    [string] Identifier() { return $this.Subnet }
    static [hashtable] IdentifierParams([string] $identifier) { return @{ Subnet = $identifier } }
    static [List[LisSubnet]] GetAll() {
        return [LisSubnet]::GetAll($false)
    }
    static [List[LisSubnet]] GetAll([bool] $ForceUpdate) {
        if ($null -eq [LisSubnet]::_getItemCommand) {
            [LisSubnet]::_getItemCommand = Get-Command -Name Get-CsOnlineLisSubnet
        }
        return [LisSubnet[]][LisObject]::_getAll([LisSubnet], [LisSubnet]::_getItemCommand, $ForceUpdate)
    }
    static [LisSubnet] Get([string] $identifier) {
        return [LisSubnet]::Get($identifier, $false)
    }
    static [LisSubnet] Get([string] $identifier, [bool] $ForceUpdate) {
        if ($null -eq [LisSubnet]::_getItemCommand) {
            [LisSubnet]::_getItemCommand = Get-Command -Name Get-CsOnlineLisSubnet
        }
        return [LisSubnet][LisObject]::_get([LisSubnet], [LisSubnet]::_getItemCommand, $identifier, @{}, $ForceUpdate)
    }
}

class LisWirelessAccessPoint : LisNetworkObject {
    hidden static [CommandInfo] $_getItemCommand = $null
    [string] $BSSID
    LisWirelessAccessPoint() {}
    LisWirelessAccessPoint([object] $obj) : base($obj) {}
    [string] Identifier() { return $this.BSSID }
    static [hashtable] IdentifierParams([string] $identifier) { return @{ BSSID = $identifier } }
    static [List[LisWirelessAccessPoint]] GetAll() {
        return [LisWirelessAccessPoint]::GetAll($false)
    }
    static [List[LisWirelessAccessPoint]] GetAll([bool] $ForceUpdate) {
        if ($null -eq [LisWirelessAccessPoint]::_getItemCommand) {
            [LisWirelessAccessPoint]::_getItemCommand = Get-Command -Name Get-CsOnlineLisWirelessAccessPoint
        }
        return [LisWirelessAccessPoint[]][LisObject]::_getAll([LisWirelessAccessPoint], [LisWirelessAccessPoint]::_getItemCommand, $ForceUpdate)
    }
    static [LisWirelessAccessPoint] Get([string] $identifier) {
        return [LisWirelessAccessPoint]::Get($identifier, $false)
    }
    static [LisWirelessAccessPoint] Get([string] $identifier, [bool] $ForceUpdate) {
        if ($null -eq [LisWirelessAccessPoint]::_getItemCommand) {
            [LisWirelessAccessPoint]::_getItemCommand = Get-Command -Name Get-CsOnlineLisWirelessAccessPoint
        }
        return [LisWirelessAccessPoint][LisObject]::_get([LisWirelessAccessPoint], [LisWirelessAccessPoint]::_getItemCommand, $identifier, @{}, $ForceUpdate)
    }
}

class LisObjectHelper {
    static [Dictionary[string, List[LisObject]]] GetAll() {
        return [LisObjectHelper]::GetAll($false, $false)
    }
    static [Dictionary[string, List[LisObject]]] GetAll([bool] $ForceUpdate) {
        return [LisObjectHelper]::GetAll($false, $ForceUpdate)
    }
    static [Dictionary[string, List[LisObject]]] GetAll([bool] $IncludeOrphaned, [bool] $ForceUpdate) {
        $result = [Dictionary[string, List[LisObject]]]@{}
        # get the locaitons and address first to try and pull everything
        [LisObjectHelper]::LoadCache($ForceUpdate)
        # check for orphaned status to force a point query on a cache miss
        $result.Add('LisPort', [LisPort[]][LisPort]::GetAll().Where({ !$_.IsOrphaned() -or $IncludeOrphaned }))
        $result.Add('LisSwitch', [LisSwitch[]][LisSwitch]::GetAll().Where({ !$_.IsOrphaned() -or $IncludeOrphaned }))
        $result.Add('LisSubnet', [LisSubnet[]][LisSubnet]::GetAll().Where({ !$_.IsOrphaned() -or $IncludeOrphaned }))
        $result.Add('LisWirelessAccessPoint', [LisWirelessAccessPoint[]][LisWirelessAccessPoint]::GetAll().Where({ !$_.IsOrphaned() -or $IncludeOrphaned }))
        # now add all locations and address to the result set
        $result.Add('LisLocation', [LisLocation[]][LisLocation]::GetAll().Where({ !$_.IsOrphaned() -or $IncludeOrphaned }))
        $result.Add('LisCivicAddress', [LisCivicAddress[]][LisCivicAddress]::GetAll())
        return $result
    }
    static [void] LoadCache() {
        [LisObjectHelper]::LoadCache($false)
    }
    static [void] LoadCache([bool] $ForceUpdate) {
        # get the locations and address first to try and pull everything
        # try and populate any usage data as well
        Write-Information 'Loading LisLocation cache'
        $lCount = [LisLocation]::GetAll($ForceUpdate).Count
        Write-Information ('Cached {0} LisLocation objects' -f $lCount)

        Write-Information 'Loading LisCivicAddress cache'
        $aCount = [LisCivicAddress]::GetAll($ForceUpdate).Count
        Write-Information ('Cached {0} LisCivicAddress objects' -f $aCount)
        # check for orphaned status to force a point query on a cache miss
        Write-Information 'Loading LisNetworkObject cache'
        $nCount = [LisNetworkObject]::GetAll($true, $ForceUpdate).Where({ !$_.IsOrphaned() }).Count
        Write-Information ('Cached {0} LisNetworkObject objects' -f $nCount)
        # now add all locations and address to the result set
        Write-Information 'Checking for Missed Locations'
        $lCount1 = [LisLocation]::GetAll($false).Count
        Write-Information ('Cached {0} additional LisLocation objects' -f ($lCount1 - $lCount))

        Write-Information 'Checking for Missed Addresses'
        $aCount2 = [LisCivicAddress]::GetAll($false).Count
        Write-Information ('Cached {0} additional LisCivicAddress objects' -f ($aCount2 - $aCount))
    }
    static [void] LoadCache([PSFunctionHost] $parent) {
        [LisObjectHelper]::LoadCache($parent, $false)
    }
    static [void] LoadCache([PSFunctionHost] $parent, [bool] $ForceUpdate) {
        $cacheHelper = [PSFunctionHost]::new($parent, 'Caching LIS Objects')
        try {
            # get the locations and address first to try and pull everything
            # try and populate any usage data as well
            $cacheHelper.WriteVerbose('Loading LisLocation cache')
            $cacheHelper.ForceUpdate('Loading LisLocation cache')
            $lCount = [LisLocation]::GetAll($ForceUpdate).Count
            $cacheHelper.WriteVerbose(('Cached {0} LisLocation objects' -f $lCount))

            $cacheHelper.WriteVerbose('Loading LisCivicAddress cache')
            $cacheHelper.ForceUpdate('Loading LisCivicAddress cache')
            $aCount = [LisCivicAddress]::GetAll($ForceUpdate).Count
            $cacheHelper.WriteVerbose(('Cached {0} LisCivicAddress objects' -f $aCount))
            # check for orphaned status to force a point query on a cache miss
            $cacheHelper.WriteVerbose('Loading LisNetworkObject cache')
            $cacheHelper.ForceUpdate('Loading LisNetworkObject cache')
            $nCount = [LisNetworkObject]::GetAll($true, $ForceUpdate).Where({ !$_.IsOrphaned() }).Count
            $cacheHelper.WriteVerbose(('Cached {0} LisNetworkObject objects' -f $nCount))
            # now add all locations and address to the result set
            $cacheHelper.WriteVerbose('Checking for Missed Locations')
            $cacheHelper.ForceUpdate('Checking for Missed Locations')
            $lCount1 = [LisLocation]::GetAll($false).Count
            $cacheHelper.WriteVerbose(('Cached {0} additional LisLocation objects' -f ($lCount1 - $lCount)))

            $cacheHelper.WriteVerbose('Checking for Missed Addresses')
            $cacheHelper.ForceUpdate('Checking for Missed Addresses')
            $aCount2 = [LisCivicAddress]::GetAll($false).Count
            $cacheHelper.WriteVerbose(('Cached {0} additional LisCivicAddress objects' -f ($aCount2 - $aCount)))
        }
        finally {
            $cacheHelper.Dispose()
        }
    }
}

class LisLocationEqualityComparer : IEqualityComparer[object] {
    [bool] Equals([object]$x, [object]$y) {
        if ($this.GetHashCode($x) -ne $this.GetHashCode($y)) { return $false }
        if ($null -eq $x) { return $null -eq $y }
        if ($null -eq $y) { return $false }
        $xl = $x -as [LisLocation]
        $yl = $y -as [LisLocation]
        return $xl.GetHash() -eq $yl.GetHash()
    }
    [int] GetHashCode([object]$obj) {
        if ($null -eq $obj) { return 0 }
        $l = $obj -as [LisLocation]
        return $l.GetHash().GetHashCode()
    }
}

class LisLocationPrioritySet : HashSet[object] {
    LisLocationPrioritySet() : base([LisLocationEqualityComparer]::new()) {}
    LisLocationPrioritySet([IEnumerable[object]] $collection) : base([LisLocationEqualityComparer]::new()) {
        $this.UnionWith($collection)
    }
    LisLocationPrioritySet([int] $capacity) : base($capacity,[LisLocationEqualityComparer]::new()) {}

    [bool] Add([object] $obj) {
        if ($null -eq $obj) { return $false }
        $location = $obj -as [LisLocation]
        $existingLocation = $this.GetDuplicateLocation($location)
        if ($null -ne $existingLocation) {
            $priority = $existingLocation.ComparePriorityTo($location)
            if ($priority -le 0) { return $false }
            $this.Remove($existingLocation)
            ([HashSet[object]]$this).Add($location)
            return $true
        }
        ([HashSet[object]]$this).Add($location)
        return $true
    }

    [void] UnionWith([IEnumerable[object]] $other) {
        if ($null -eq $other) { throw [ArgumentNullException]::new("other") }
        foreach ($location in $other) {
            $this.Add($location)
        }
    }

    [bool] Contains([object] $obj) {
        if ($null -eq $obj) { return $false }
        $existingLocation = $this.GetDuplicateLocation($obj)
        if ($null -ne $existingLocation) {
            return [object]::ReferenceEquals($existingLocation, $obj)
        }
        return $false
    }

    [LisLocation] GetDuplicateLocation([LisLocation] $location) {
        if ($null -eq $location) { return $null }
        $existingLocation = $null
        if ($this.TryGetValue($location, [ref] $existingLocation)) {}
        return $existingLocation
    }
}