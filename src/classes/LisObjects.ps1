using namespace System.Collections.Generic
using namespace System.Management.Automation
using namespace System.Reflection
using namespace System.Text

class LisObject {
    LisObject() {}
    LisObject([object] $obj) {}
}

class LisNetworkObject : LisObject {
    [Guid] $LocationId
    [string] $Description
    [string] $Type
    LisNetworkObject() {}
    LisNetworkObject([object] $obj) : base($obj) {
        $this.LocationId = $obj.LocationId
        $this.Description = $obj.Description
    }
    [string] Identifier() { return '' }
    [bool] IsOrphaned() {
        $location = $this.GetLocation()
        return $null -eq $location -or $location.IsOrphaned()
    }
    hidden static [List[LisNetworkObject]] $All = $null
    static [List[LisNetworkObject]] GetAllInitial() {
        if ($null -eq [LisNetworkObject]::All) {
            [LisNetworkObject]::All = @()
            $obj = [LisPort]::GetAll()
            if ($obj.Count -gt 0) { [LisNetworkObject]::All.AddRange($obj) }
            $obj = [LisSwitch]::GetAll()
            if ($obj.Count -gt 0) { [LisNetworkObject]::All.AddRange($obj) }
            $obj = [LisSubnet]::GetAll()
            if ($obj.Count -gt 0) { [LisNetworkObject]::All.AddRange($obj) }
            $obj = [LisWirelessAccessPoint]::GetAll()
            if ($obj.Count -gt 0) { [LisNetworkObject]::All.AddRange($obj) }
        }
        return [LisNetworkObject]::All
    }
    static [List[LisNetworkObject]] GetAll() {
        return [LisNetworkObject]::GetAllInitial()
    }
    static [List[LisNetworkObject]] GetAll([Guid] $LocationId) {
        $result = [List[LisNetworkObject]]@()
        $obj = [LisPort]::GetAll($LocationId)
        if ($obj.Count -gt 0) { $result.AddRange($obj) }
        $obj = [LisSwitch]::GetAll($LocationId)
        if ($obj.Count -gt 0) { $result.AddRange($obj) }
        $obj = [LisSubnet]::GetAll($LocationId)
        if ($obj.Count -gt 0) { $result.AddRange($obj) }
        $obj = [LisWirelessAccessPoint]::GetAll($LocationId)
        if ($obj.Count -gt 0) { $result.AddRange($obj) }
        return $result
    }
    static [List[LisNetworkObject]] GetAll([Func[LisNetworkObject, bool]] $Filter) {
        return [LisNetworkObject[]][LisNetworkObject]::GetAllInitial().Where({ $Filter.Invoke($_) })
    }
    hidden [LisLocation] $_location = $null
    hidden [LisCivicAddress] $_civicAddress = $null
    [LisLocation] GetLocation() {
        if ($null -eq $this._location) {
            $this._location = [LisLocation]::GetById($this.LocationId)
        }
        return $this._location
    }
    [LisCivicAddress] GetCivicAddress() {
        if ($null -eq $this._civicAddress) {
            $location = $this.GetLocation()
            $this._civicAddress = [LisCivicAddress]::GetById($location.CivicAddressId)
        }
        return $this._civicAddress
    }
}

class LisAddressBase : LisObject {
    static [bool] $CompareNumbers = $false
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
    LisAddressBase() {}
    LisAddressBase([object] $obj) : base($obj) {
        $this.CivicAddressId = $obj.CivicAddressId
        $this.CompanyName = $obj.CompanyName
        $this.CompanyTaxId = $obj.CompanyTaxId
        $this.HouseNumber = $obj.HouseNumber
        $this.HouseNumberSuffix = $obj.HouseNumberSuffix
        $this.PreDirectional = $obj.PreDirectional
        $this.StreetName = $obj.StreetName
        $this.StreetSuffix = $obj.StreetSuffix
        $this.PostDirectional = $obj.PostDirectional
        $this.City = $obj.City
        $this.PostalCode = $obj.PostalCode
        $this.StateOrProvince = $obj.StateOrProvince
        $this.CountryOrRegion = $obj.CountryOrRegion
        $this.Description = $obj.Description
        $this.Latitude = $obj.Latitude
        $this.Longitude = $obj.Longitude
        $this.Elin = $obj.Elin
        $this.NumberOfVoiceUsers = $obj.NumberOfVoiceUsers
        $this.NumberOfTelephoneNumbers = $obj.NumberOfTelephoneNumbers
    }

    hidden [bool] $_IsInUseCheckDone = $false
    hidden [bool] $_IsInUse = $false
    [bool] IsInUse() {
        if ($this._IsInUseCheckDone) { return $this._IsInUse }
        $this._IsInUseCheckDone = $true
        if ([LisAddressBase]::CompareNumbers -and ($this.NumberOfTelephoneNumbers -eq -1 -or $this.NumberOfVoiceUsers -eq -1)) {
            if (!$this::_populateAllDone) {
                $this::GetAll({ $true }, @{ Populate = $true })
                $this::_populateAllDone = $true
            }
            $current = if ($this -is [LisLocation]) {
                Get-CsOnlineLisLocationInternal -LocationId $this.LocationId -Populate
            }
            else {
                Get-CsOnlineLisCivicAddressInternal -CivicAddressId $this.CivicAddressId -Populate
            }
            $this.NumberOfTelephoneNumbers = $current.NumberOfTelephoneNumbers
            $this.NumberOfVoiceUsers = $current.NumberOfVoiceUsers
        }
        if ($this.NumberOfTelephoneNumbers -gt 0 -or $this.NumberOfVoiceUsers -gt 0) { return $this._IsInUse = $true }
        if ($this.GetAssociatedNetworkObjects().Count -gt 0) { return $this._IsInUse = $true }
        return $this._IsInUse = $false
    }
    [bool] IsValid() { throw 'Must Override Base Method' }
    [List[LisNetworkObject]] GetAssociatedNetworkObjects() { throw 'Must Override Base Method' }
    hidden [string] $_Address = $null
    static [string] ConvertAddressPartsToAddress([LisAddressBase] $address) {
        if ([string]::IsNullOrEmpty($address._Address)) { 
            $address._Address = [E911Address]::FormatOnlineAddress($address)
        }
        return $address._Address
    }
    [int] CompareTo([object] $obj) {
        if ($null -eq $obj) { return -1 }
        if ($obj -eq $this) { return 0 }
        if ($null -ne $obj.StateOrProvince -and $null -ne $this.StateOrProvince -and $obj.StateOrProvince -ne $this.StateOrProvince) {
            return [string]::Compare($this.StateOrProvince, $obj.StateOrProvince, $true)
        }
        if ($null -ne $obj.City -and $null -ne $this.City -and $obj.City -ne $this.City) {
            return [string]::Compare($this.City, $obj.City, $true)
        }
        if ($null -ne $obj.PostalCode -and $null -ne $this.PostalCode -and $obj.PostalCode -ne $this.PostalCode) {
            return [string]::Compare($this.PostalCode, $obj.PostalCode, $true)
        }
        $objAddress = $this::ConvertAddressPartsToAddress($obj)
        $thisAddress = $this::ConvertAddressPartsToAddress($this)
        return [AddressStringComparer]::Default.Compare($thisAddress, $objAddress)
    }
    hidden static [string[]] $PropertiesToCheck = @(
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
    hidden static [string[]] $RequiredProperties = @(
        'CompanyName'
        'HouseNumber'
        'StreetName'
        'City'
        'PostalCode'
        'StateOrProvince'
        'CountryOrRegion'
    )
    [string] GetHash() { throw 'Must Override Base Method' }
    [string] ToString() {
        return $this.CompanyName + ' ' + $this::ConvertAddressPartsToAddress($this)
    }
    [int] ComparePriorityTo([LisAddressBase] $obj) {
        if (!$this.ValueEquals($obj)) {
            return $this.CompareTo($obj)
        }
        $testResult = 0
        $Tests = $this::PriorityTests
        for ($i = 0; $i -lt $Tests.Count -and $testResult -eq 0; $i++) {
            $testResult = $Tests[$i].Invoke($this, $obj)
        }
        return $testResult
    }

    [bool] PossibleDuplicate([object] $obj) {
        if ($null -eq $obj) { return $false }
        if ($this.GetType() -ne $obj.GetType()) { return $false }
        $lObj = $obj -as ($this.GetType())
        if ($this.GetHash() -ne $lObj.GetHash()) { return $false }
        return $true
    }
}

class LisLocation : LisAddressBase {
    hidden static [bool] $_populateAllDone = $false

    [Guid] $LocationId
    [string] $Location
    LisLocation() {}
    LisLocation([object] $obj) : base($obj) {
        $this.LocationId = $obj.LocationId
        $this.Location = $obj.Location
    }
    [bool] IsValid() {
        if (!$this._validDone) {
            $this._validDone = $true
            if (!($this._isValid = !$this.IsOrphaned())) { return $false }
            foreach ($Prop in [LisAddressBase]::RequiredProperties) {
                if (!($this._isValid = ![string]::IsNullOrEmpty($this.$Prop))) { return $false }
            }
            $address = $this.GetCivicAddress()
            if (!($this._isValid = $address.IsValid())) { return $false }
            if ($this.LocationId -eq $address.DefaultLocationId) {
                foreach ($Prop in [LisAddressBase]::PropertiesToCheck) {
                    if (!($this._isValid = $address.$Prop -eq $this.$Prop)) { return $false }
                }
            }
            else {
                if (!($this._isValid = ![string]::IsNullOrEmpty($this.Location))) { return $false }
            }
            $this._isValid = $true
        }
        return $this._isValid
    }
    [bool] IsOrphaned() {
        return $null -eq $this.GetCivicAddress()
    }
    static [LisLocation] GetById([string] $LocationId) {
        return [LisLocation]::Get($LocationId)[0]
    }
    static [List[LisLocation]] GetAll() {
        return [LisLocation]::GetAll({ $true })
    }
    static [List[LisLocation]] GetAll([Func[LisLocation, bool]] $Filter) {
        return [LisLocation[]]@(Get-CsOnlineLisLocationInternal).Where({$_}).Where({ $Filter.Invoke($_) })
    }
    static [List[LisLocation]] GetAll([Func[LisLocation, bool]] $Filter, [hashtable] $AdditionalParams) {
        return [LisLocation[]]@(Get-CsOnlineLisLocationInternal @AdditionalParams).Where({$_}).Where({ $Filter.Invoke($_) })
    }
    static [List[LisLocation]] Get([string] $LocationId) {
        return [LisLocation[]]@(Get-CsOnlineLisLocationInternal -LocationId $LocationId).Where({$_})
    }
    hidden [List[LisNetworkObject]] $_associatedNetworkObjects = $null
    [List[LisNetworkObject]] GetAssociatedNetworkObjects() {
        if ($null -eq $this._associatedNetworkObjects) {
            $this._associatedNetworkObjects = [LisNetworkObject]::GetAll($this.LocationId)
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
        if ($null -eq $this._civicAddress) {
            $this._civicAddress = [LisCivicAddress]::GetById($this.CivicAddressId)
        }
        return $this._civicAddress
    }
    [string] ToString() {
        return ([LisAddressBase]$this).ToString() + ' ' + $this.Location
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
        return [string]::Compare($this.Location, $obj.Location, $true)
    }

    hidden static [Func[LisLocation, LisLocation, int][]] $PriorityTests = @(
        {
            param($l1, $l2)
            $l1TestSuccessful = !$l1.IsOrphaned()
            $l2TestSuccessful = !$l2.IsOrphaned()
            if (!$l2TestSuccessful) { return -1 }
            if (!$l1TestSuccessful) { return 1 }
            return 0
        }
        {
            param ($l1, $l2)
            if ($l1.CivicAddressId -eq $l2.CivicAddressId) { return 0 }
            $a1 = $l1.GetCivicAddress()
            $a2 = $l2.GetCivicAddress()
            return $a1.ComparePriorityTo($a2)
        }
        {
            param($l1, $l2)
            $l1TestSuccessful = $l1.IsValid()
            $l2TestSuccessful = $l2.IsValid()
            if ($l1TestSuccessful -and !$l2TestSuccessful) { return -1 }
            if (!$l1TestSuccessful -and $l2TestSuccessful) { return 1 }
            return 0
        }
        {
            param($l1, $l2)
            $l1TestSuccessful = ![string]::IsNullOrEmpty($l1.Description)
            $l2TestSuccessful = ![string]::IsNullOrEmpty($l2.Description)
            if ($l1TestSuccessful -and !$l2TestSuccessful) { return -1 }
            if (!$l1TestSuccessful -and $l2TestSuccessful) { return 1 }
            return 0
        }
        {
            param($l1, $l2)
            if ([string]::IsNullOrEmpty($l1.Location) -and [string]::IsNullOrEmpty($l2.Location)) { return 0 }
            $l1TestSuccessful = $l1.IsInUse()
            $l2TestSuccessful = $l2.IsInUse()
            if ($l1TestSuccessful -and !$l2TestSuccessful) { return -1 }
            if ($l2TestSuccessful -and !$l1TestSuccessful) { return 1 }
            return 0
        }
        {
            param($l1, $l2)
            $l1Count = $l1.NumberOfVoiceUsers + $l1.NumberOfTelephoneNumbers
            $l2Count = $l2.NumberOfVoiceUsers + $l2.NumberOfTelephoneNumbers
            $diff = $l2Count - $l1Count
            if ($diff -gt 0) { return 1 }
            if ($diff -lt 0) { return -1 }
            return 0
        }
        {
            param($l1, $l2)
            $l1Count = $l1.GetAssociatedNetworkObjects().Count
            $l2Count = $l2.GetAssociatedNetworkObjects().Count
            $diff = $l2Count - $l1Count
            if ($diff -gt 0) { return 1 }
            if ($diff -lt 0) { return -1 }
            return 0
        }
        {
            param($l1, $l2)
            if ($l1.CivicAddressId -eq $l2.CivicAddressId) { 
                return [string]::Compare($l1.LocationId, $l2.LocationId, $true)
            }
            return [string]::Compare($l1.CivicAddressId, $l2.CivicAddressId, $true)
        }
    )

    [bool] ValueEquals([object] $obj) {
        if (!$this.PossibleDuplicate($obj)) { return $false }
        $lObj = $obj -as [LisLocation]
        if ($lObj.Location -ne $this.Location) {
            return $false
        }
        if ($lObj.Elin -ne $this.Elin) {
            return $false
        }
        if ($lObj.CompanyName -ne $this.CompanyName) {
            return $false
        }
        if ($lObj.CompanyTaxId -ne $this.CompanyTaxId) {
            return $false
        }
        if (![string]::IsNullOrEmpty($lObj.City) -and ![string]::IsNullOrEmpty($this.City) -and $lObj.City -ne $this.City) {
            return $false
        }
        if (![string]::IsNullOrEmpty($lObj.PostalCode) -and ![string]::IsNullOrEmpty($this.PostalCode) -and $lObj.PostalCode -ne $this.PostalCode) {
            return $false
        }
        if (![string]::IsNullOrEmpty($lObj.StateOrProvince) -and ![string]::IsNullOrEmpty($this.StateOrProvince) -and $lObj.StateOrProvince -ne $this.StateOrProvince) {
            return $false
        }
        if (![string]::IsNullOrEmpty($lObj.CountryOrRegion) -and ![string]::IsNullOrEmpty($this.CountryOrRegion) -and $lObj.CountryOrRegion -ne $this.CountryOrRegion) {
            return $false
        }
        if (![string]::IsNullOrEmpty($lObj.Latitude) -and ![string]::IsNullOrEmpty($this.Latitude) -and $lObj.Latitude -ne $this.Latitude) {
            return $false
        }
        if (![string]::IsNullOrEmpty($lObj.Longitude) -and ![string]::IsNullOrEmpty($this.Longitude) -and $lObj.Longitude -ne $this.Longitude) {
            return $false
        }
        
        $lObjAddr = [AddressFormatter]::Default.GetComparableAddress([LisAddressBase]::ConvertAddressPartsToAddress($lObj))
        $thisAddr = [AddressFormatter]::Default.GetComparableAddress([LisAddressBase]::ConvertAddressPartsToAddress($this))
        if ($lObjAddr -ne $thisAddr) {
            return $false
        }
        return $true
    }
}

class LisCivicAddress : LisAddressBase {
    hidden static [bool] $_populateAllDone = $false

    [Guid] $DefaultLocationId
    LisCivicAddress() {}
    LisCivicAddress([object] $obj) : base($obj) {
        $this.DefaultLocationId = $obj.DefaultLocationId
    }

    [bool] IsValid() {
        if (!$this._validDone) {
            $this._validDone = $true
            foreach ($Prop in [LisAddressBase]::RequiredProperties) {
                if (!($this._isValid = ![string]::IsNullOrEmpty($this.$Prop))) { 
                    $this.InvalidateLocations()
                    return $false
                }
            }
            if (!($this._isValid = $null -ne ($location = $this.GetDefaultLocation()))) { 
                $this.InvalidateLocations()
                return $false
            }
            foreach ($Prop in [LisAddressBase]::PropertiesToCheck) {
                if (!($this._isValid = $location.$Prop -eq $this.$Prop)) { 
                    $this.InvalidateLocations()
                    return $false
                }
            }
            $this._isValid = $true
        }
        return $this._isValid
    }
    hidden [void] InvalidateLocations() {
        foreach ($location in $this.GetAssociatedLocations()) {
            $location._isValid = $false
            $location._validDone = $true
        }
    }

    hidden [LisLocation] $_defaultLocation = $null
    [LisLocation] GetDefaultLocation() {
        if ($null -eq $this._defaultLocation) {
            $this._defaultLocation = [LisLocation]::GetById($this.DefaultLocationId)
        }
        return $this._defaultLocation
    }

    static [LisCivicAddress] GetById([string] $CivicAddressId) {
        return [LisCivicAddress]::Get($CivicAddressId)[0]
    }
    static [List[LisCivicAddress]] GetAll() {
        return [LisCivicAddress[]]@(Get-CsOnlineLisCivicAddressInternal).Where({$_})
    }
    static [List[LisCivicAddress]] Get([string] $CivicAddressId) {
        return [LisCivicAddress[]]@(Get-CsOnlineLisCivicAddressInternal -CivicAddressId $CivicAddressId).Where({$_})
    }
    static [List[LisCivicAddress]] GetAll([Func[LisAddressBase,bool]] $Filter, [hashtable] $AdditionalParams) {
        return [LisCivicAddress[]]@(Get-CsOnlineLisCivicAddressInternal @AdditionalParams).Where({$_}).Where({ $Filter.Invoke($_) })
    }
    hidden [List[LisLocation]] $_associatedLocations = $null
    [List[LisLocation]] GetAssociatedLocations() {
        if ($null -eq $this._associatedLocations) {
            $this._associatedLocations = [LisLocation]::GetAll({ $true }, @{ CivicAddressId = $this.CivicAddressId })
        }
        return $this._associatedLocations
    }

    hidden [List[LisNetworkObject]] $_associatedNetworkObjects = $null
    [List[LisNetworkObject]] GetAssociatedNetworkObjects() {
        if ($null -eq $this._associatedNetworkObjects) {
            $this._associatedNetworkObjects = [List[LisNetworkObject]]@()
            foreach ($location in $this.GetAssociatedLocations()) {
                $networkObjects = $location.GetAssociatedNetworkObjects()
                if ($networkObjects.Count -gt 0) {
                    $this._associatedNetworkObjects.AddRange($location.GetAssociatedNetworkObjects())
                }
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
        if ($null -eq $hash['Address']) { $hash['Address'] = '' }
        if ([string]::IsNullOrEmpty($hash['Elin'])) { $hash['Elin'] = '' }
        $newOAddr = [E911Address]::new($true)
        foreach ($key in $hash.Keys) {
            $newOAddr.$key = $hash[$key]
        }
        return $newOAddr
    }

    hidden static [Func[LisCivicAddress, LisCivicAddress, int][]] $PriorityTests = @(
        {
            param($a1, $a2)
            $a1TestSuccessful = $a1.IsValid()
            $a2TestSuccessful = $a2.IsValid()
            if (!$a2TestSuccessful) { return -1 }
            if (!$a1TestSuccessful) { return 1 }
            return 0
        }
        {
            param($a1, $a2)
            $a1TestSuccessful = ($a1.Longitude -replace '0', '').Length -gt 1 -and ($a1.Latitude -replace '0', '').Length -gt 1
            $a2TestSuccessful = ($a2.Longitude -replace '0', '').Length -gt 1 -and ($a2.Latitude -replace '0', '').Length -gt 1
            if ($a1TestSuccessful -and !$a2TestSuccessful) { return -1 }
            if ($a2TestSuccessful -and !$a1TestSuccessful) { return 1 }
            return 0
        }
        {
            param($a1, $a2)
            $a1TestSuccessful = ![string]::IsNullOrEmpty($a1.Description)
            $a2TestSuccessful = ![string]::IsNullOrEmpty($a2.Description)
            if ($a1TestSuccessful -and !$a2TestSuccessful) { return -1 }
            if ($a2TestSuccessful -and !$a1TestSuccessful) { return 1 }
            return 0
        }
        {
            param($a1, $a2)
            $a1TestSuccessful = $a1.IsInUse()
            $a2TestSuccessful = $a2.IsInUse()
            if ($a1TestSuccessful -and !$a2TestSuccessful) { return -1 }
            if ($a2TestSuccessful -and !$a1TestSuccessful) { return 1 }
            return 0
        }
        {
            param($a1, $a2)
            $a1Count = $a1.GetAssociatedNetworkObjects().Count
            $a2Count = $a2.GetAssociatedNetworkObjects().Count
            $diff = $a2Count - $a1Count
            if ($diff -gt 0) { return 1 }
            if ($diff -lt 0) { return -1 }
            return 0
        }
        {
            param($a1, $a2)
            $a1Count = $a1.NumberOfVoiceUsers + $a1.NumberOfTelephoneNumbers
            $a2Count = $a2.NumberOfVoiceUsers + $a2.NumberOfTelephoneNumbers
            $diff = $a2Count - $a1Count
            if ($diff -gt 0) { return 1 }
            if ($diff -lt 0) { return -1 }
            return 0
        }
        {
            param($a1, $a2)
            $a1Count = $a1.GetAssociatedLocations().Count
            $a2Count = $a2.GetAssociatedLocations().Count
            $diff = $a2Count - $a1Count
            if ($diff -gt 0) { return 1 }
            if ($diff -lt 0) { return -1 }
            return 0
        }
        {
            param($a1, $a2)
            return [string]::Compare($a1.CivicAddressId, $a2.CivicAddressId, $true)
        }
    )

    [bool] ValueEquals([object] $obj) {
        if (!$this.PossibleDuplicate($obj)) { return $false }
        $lObj = $obj -as [LisCivicAddress]
        if ($lObj.CompanyName -ne $this.CompanyName) {
            return $false
        }
        if ($lObj.CompanyTaxId -ne $this.CompanyTaxId) {
            return $false
        }
        if (![string]::IsNullOrEmpty($lObj.City) -and ![string]::IsNullOrEmpty($this.City) -and $lObj.City -ne $this.City) {
            return $false
        }
        if (![string]::IsNullOrEmpty($lObj.PostalCode) -and ![string]::IsNullOrEmpty($this.PostalCode) -and $lObj.PostalCode -ne $this.PostalCode) {
            return $false
        }
        if (![string]::IsNullOrEmpty($lObj.StateOrProvince) -and ![string]::IsNullOrEmpty($this.StateOrProvince) -and $lObj.StateOrProvince -ne $this.StateOrProvince) {
            return $false
        }
        if (![string]::IsNullOrEmpty($lObj.CountryOrRegion) -and ![string]::IsNullOrEmpty($this.CountryOrRegion) -and $lObj.CountryOrRegion -ne $this.CountryOrRegion) {
            return $false
        }
        if (![string]::IsNullOrEmpty($lObj.Latitude) -and ![string]::IsNullOrEmpty($this.Latitude) -and $lObj.Latitude -ne $this.Latitude) {
            return $false
        }
        if (![string]::IsNullOrEmpty($lObj.Longitude) -and ![string]::IsNullOrEmpty($this.Longitude) -and $lObj.Longitude -ne $this.Longitude) {
            return $false
        }
        $lObjAddr = [AddressFormatter]::Default.GetComparableAddress([LisAddressBase]::ConvertAddressPartsToAddress($lObj))
        $thisAddr = [AddressFormatter]::Default.GetComparableAddress([LisAddressBase]::ConvertAddressPartsToAddress($this))
        if ($lObjAddr -ne $thisAddr) {
            return $false
        }
        return $true
    }
}

class LisPort : LisNetworkObject {
    [string] $Type = 'Port'
    [string] $ChassisId
    [string] $PortId
    LisPort() {}
    LisPort([object] $obj) : base($obj) {
        $this.ChassisId = $obj.ChassisId
        $this.PortId = $obj.PortId
    }
    [string] Identifier() {
        return $this.ChassisId + ';' + $this.PortId
    }
    static [List[LisPort]] GetAll() {
        return [LisPort[]]@(Get-CsOnlineLisPortInternal).Where({$_})
    }
    static [List[LisPort]] GetAll([Guid] $LocationId) {
        return [LisPort[]]@(Get-CsOnlineLisPortInternal -LocationId $LocationId.ToString()).Where({$_})
    }
    static [LisPort] Get([string] $identifier) {
        $Chassis, $Port = $identifier.Split(';')
        return [LisPort]@(Get-CsOnlineLisPortInternal -ChassisID $Chassis -PortID $Port).Where({$_})
    }
    static [LisPort] Get([string] $ChassisID, [string] $PortId) {
        return [LisPort]::Get($ChassisID + ';' + $PortID)
    }
}

class LisSwitch : LisNetworkObject {
    [string] $Type = 'Switch'
    [string] $ChassisId
    LisSwitch() {}
    LisSwitch([object] $obj) : base($obj) {
        $this.ChassisId = $obj.ChassisId
    }
    [string] Identifier() {
        return $this.ChassisId
    }
    static [List[LisSwitch]] GetAll() {
        return [LisSwitch[]]@(Get-CsOnlineLisSwitchInternal).Where({$_})
    }
    static [List[LisSwitch]] GetAll([Guid] $LocationId) {
        return [LisSwitch[]]@(Get-CsOnlineLisSwitchInternal -LocationId $LocationId.ToString()).Where({$_})
    }
    static [LisSwitch] Get([string] $identifier) {
        return [LisSwitch]@(Get-CsOnlineLisSwitchInternal -ChassisID $identifier).Where({$_})
    }
}

class LisSubnet : LisNetworkObject {
    [string] $Type = 'Subnet'
    [string] $Subnet
    LisSubnet() {}
    LisSubnet([object] $obj) : base($obj) {
        $this.Subnet = $obj.Subnet
    }
    [string] Identifier() {
        return $this.Subnet
    }
    static [List[LisSubnet]] GetAll() {
        return [LisSubnet[]]@(Get-CsOnlineLisSubnetInternal).Where({$_})
    }
    static [List[LisSubnet]] GetAll([Guid] $LocationId) {
        return [LisSubnet[]]@(Get-CsOnlineLisSubnetInternal -LocationId $LocationId.ToString()).Where({$_})
    }
    static [LisSubnet] Get([string] $identifier) {
        return [LisSubnet]@(Get-CsOnlineLisSubnetInternal -Subnet $identifier).Where({$_})
    }
}

class LisWirelessAccessPoint : LisNetworkObject {
    [string] $Type = 'WirelessAccessPoint'
    [string] $BSSID
    LisWirelessAccessPoint() {}
    LisWirelessAccessPoint([object] $obj) : base($obj) {
        $this.BSSID = $obj.BSSID
    }
    [string] Identifier() {
        return $this.BSSID
    }
    static [List[LisWirelessAccessPoint]] GetAll() {
        return [LisWirelessAccessPoint[]]@(Get-CsOnlineLisWirelessAccessPointInternal).Where({$_})
    }
    static [List[LisWirelessAccessPoint]] GetAll([Guid] $LocationId) {
        return [LisWirelessAccessPoint[]]@(Get-CsOnlineLisWirelessAccessPointInternal -LocationId $LocationId.ToString()).Where({$_})
    }
    static [LisWirelessAccessPoint] Get([string] $identifier) {
        return [LisWirelessAccessPoint]@(Get-CsOnlineLisWirelessAccessPointInternal -BSSID $identifier).Where({$_})
    }
}

class LisObjectHelper {
    static [void] LoadCache() {
        [LisObjectHelper]::LoadCache($false)
    }
    static [void] LoadCache([bool] $ForceUpdate) {
        if ($ForceUpdate) { Reset-CsOnlineLisCache }

        # get the locations and address first to try and pull everything
        # try and populate any usage data as well
        Write-Information 'Loading LisCivicAddress cache'
        $civicAddress = [LisCivicAddress]::GetAll()
        $aCount = $civicAddress.Count
        Write-Information ('Cached {0} LisCivicAddress objects' -f $aCount)

        Write-Information 'Loading LisLocation cache'
        $lCount = [LisLocation]::GetAll().Count
        if ($lCount -eq 0) {
            foreach ($address in $civicAddress) {
                $null = $address.GetAssociatedLocations()
            }
            $lCount = [LisLocation]::GetAll().Count
        }
        Write-Information ('Cached {0} LisLocation objects' -f $lCount)

        # check for orphaned status to force a point query on a cache miss
        Write-Information 'Loading LisNetworkObject cache'
        $nCount = [LisNetworkObject]::GetAll({ !$args[0].IsOrphaned() -or $true }).Count
        Write-Information ('Cached {0} LisNetworkObject objects' -f $nCount)
    }
    static [void] LoadCache([PSFunctionHost] $parent) {
        [LisObjectHelper]::LoadCache($parent, $false)
    }
    static [void] LoadCache([PSFunctionHost] $parent, [bool] $ForceUpdate) {
        $cacheHelper = [PSFunctionHost]::new($parent, 'Caching LIS Objects')
        try {
            if ($ForceUpdate) { Reset-CsOnlineLisCache }
            $cacheHelper.WriteVerbose('Loading LisCivicAddress cache')
            $cacheHelper.ForceUpdate('Loading LisCivicAddress cache')
            $civicAddress = [LisCivicAddress]::GetAll()
            $aCount = $civicAddress.Count
            $cacheHelper.WriteVerbose(('Cached {0} LisCivicAddress objects' -f $aCount))

            $cacheHelper.WriteVerbose('Loading LisLocation cache')
            $cacheHelper.ForceUpdate('Loading LisLocation cache')
            $lCount = [LisLocation]::GetAll().Count
            if ($lCount -eq 0) {
                # if we have no locations returned, the bulk export timed out, try to get them via the address
                foreach ($address in $civicAddress) {
                    $null = $address.GetAssociatedLocations()
                }
                $lCount = [LisLocation]::GetAll().Count
            }
            $cacheHelper.WriteVerbose(('Cached {0} LisLocation objects' -f $lCount))

            $cacheHelper.WriteVerbose('Loading LisNetworkObject cache')
            $cacheHelper.ForceUpdate('Loading LisNetworkObject cache')
            # The IsOrphanedCheck forces a point query on a cache miss for locations and addresses
            $nCount = [LisNetworkObject]::GetAll({ !$args[0].IsOrphaned() -or $true }).Count
            $cacheHelper.WriteVerbose(('Cached {0} LisNetworkObject objects' -f $nCount))
        }
        finally {
            $cacheHelper.Dispose()
        }
    }
}

class LisAddressBaseEqualityComparer : IEqualityComparer[object] {
    [bool] Equals([object]$x, [object]$y) {
        if ($null -eq $x) { return $false }
        if ($x.GetType() -ne $y.GetType()) { return $false }
        $r = $x.CompareTo($y)
        if ($r -eq 0) { return $true }
        return $x.ValueEquals($y)
    }
    [int] GetHashCode([object]$obj) {
        if ($null -eq $obj) { return 0 }
        return $obj.GetHash().GetHashCode()
    }

    hidden static [string[]] $PropertiesToCheck = @(
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
}

class LisAddressBasePrioritySet : HashSet[object] {
    LisAddressBasePrioritySet() : base([LisAddressBaseEqualityComparer]::new()) {}
    LisAddressBasePrioritySet([IEnumerable[object]] $collection) : base([LisAddressBaseEqualityComparer]::new()) {
        $this.UnionWith($collection)
    }
    LisAddressBasePrioritySet([int] $capacity) : base($capacity, [LisAddressBaseEqualityComparer]::new()) {}

    LisAddressBasePrioritySet([IEnumerable[object]] $collection, [PSFunctionHost] $parent) : base([LisAddressBaseEqualityComparer]::new()) {
        $thisProcess = [PSFunctionHost]::StartNew($parent, 'Detecting Duplicates')
        try {
            $this.UnionWith($collection, $thisProcess)
        }
        finally {
            if ($null -ne $thisProcess) {
                $thisProcess.Dispose()
            }
        }
    }

    [bool] Add([object] $obj) {
        if ($null -eq $obj) { return $false }
        $existingAddressBase = $this.GetDuplicate($obj)
        if ($null -ne $existingAddressBase) {
            $priority = $existingAddressBase.ComparePriorityTo($obj)
            if ($priority -le 0) { return $false } # higher value means lower priority
            $this.Remove($existingAddressBase)
        }
        ([HashSet[object]]$this).Add($obj)
        return $true
    }

    [void] UnionWith([IEnumerable[object]] $other) {
        if ($null -eq $other) { throw [ArgumentNullException]::new('other') }
        foreach ($addressBase in $other) {
            $this.Add($addressBase)
        }
    }

    [void] UnionWith([IEnumerable[object]] $other, [PSFunctionHost] $functionHost) {
        if ($null -eq $other) { throw [ArgumentNullException]::new('other') }
        $functionHost.Total = $other.Count
        $duplicates = 0
        $type = $other[0]
        if ($null -ne $other[0]) {
            $type = $other[0].GetType().Name
        }
        foreach ($addressBase in $other) {
            $functionHost.Update($true, ('Processing {0}: {1} duplicate(s) found so far' -f $type, $duplicates))
            if(!$this.Add($addressBase)) {
                $duplicates++
                $functionHost.ForceUpdate($false, ('Processing {0}: {1} duplicate(s) found so far' -f $type, $duplicates))
                $functionHost.WriteWarning(('Duplicate found for: {0}' -f $addressBase))
            }
        }
    }

    [bool] Contains([object] $obj) {
        if ($null -eq $obj) { return $false }
        $existingAddressBase = $this.GetDuplicate($obj)
        if ($null -ne $existingAddressBase) {
            return [object]::ReferenceEquals($existingAddressBase, $obj)
        }
        return $false
    }

    [LisAddressBase] GetDuplicate([LisAddressBase] $addressBase) {
        if ($null -eq $addressBase) { return $null }
        $existingAddressBase = $null
        if ($this.TryGetValue($addressBase, [ref] $existingAddressBase)) {}
        return $existingAddressBase
    }
}

function Reset-CsOnlineLisCache {
    [CmdletBinding()]
    param ()
    end {
        if ($null -ne $script:Missing) { $null = $Missing.Clear() }
        if ($null -ne $script:LisCivicAddressCache) { $null = $LisCivicAddressCache.Clear() }
        if ($null -ne $script:LisCivicAddressCachePopulated) { $null = $LisCivicAddressCachePopulated.Clear() }
        if ($null -ne $script:LisLocationCache) { $null = $LisLocationCache.Clear() }
        if ($null -ne $script:LisLocationCachePopulated) { $null = $LisLocationCachePopulated.Clear() }
        if ($null -ne $script:LisLocationByCivicAddressCache) { $null = $LisLocationByCivicAddressCache.Clear() }
        if ($null -ne $script:LisLocationByCivicAddressCachePopulated) { $null = $LisLocationByCivicAddressCachePopulated.Clear() }
        $script:BulkAddressPopulatedDone = $false
        $script:BulkAddressDone = $false
        $script:BulkLocationPopulatedDone = $false
        $script:BulkLocationDone = $false
        $script:BulkPortDone = $false
        $script:BulkSwitchDone = $false
        $script:BulkSubnetDone = $false
        $script:BulkWirelessAccessPointDone = $false
    }
}

function Get-CsOnlineLisCivicAddressInternal {
    [CmdletBinding(DefaultParameterSetName = 'Bulk')]
    [OutputType([LisCivicAddress])]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'Point')]
        [Parameter(Mandatory = $true, ParameterSetName = 'PointPopulate')]
        [string]
        $CivicAddressId,

        [Parameter(Mandatory = $true, ParameterSetName = 'PointPopulate')]
        [Parameter(Mandatory = $true, ParameterSetName = 'BulkPopulate')]
        [switch]
        $Populate
    )
    end {
        if ($null -eq $script:Missing) { $script:Missing = [HashSet[string]]::new([StringComparer]::InvariantCultureIgnoreCase) }
        if ($null -eq $script:LisCivicAddressCache) { $script:LisCivicAddressCache = [Dictionary[string, LisCivicAddress]]::new([StringComparer]::InvariantCultureIgnoreCase) }
        if ($null -eq $script:LisCivicAddressCachePopulated) { $script:LisCivicAddressCachePopulated = [Dictionary[string, LisCivicAddress]]::new([StringComparer]::InvariantCultureIgnoreCase) }
        if ($PSCmdlet.ParameterSetName -eq 'Point') {
            if ($Missing.Contains($CivicAddressId)) { return $null }
            $existing = $null
            if ($LisCivicAddressCache.TryGetValue($CivicAddressId, [ref] $existing)) {
                return $existing
            }
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'PointPopulate') {
            if ($Missing.Contains($CivicAddressId)) { return $null }
            $existing = $null
            if ($LisCivicAddressCachePopulated.TryGetValue($CivicAddressId, [ref] $existing)) {
                return $existing
            }
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'Bulk') {
            if ($script:BulkAddressDone) {
                return [LisCivicAddress[]]$LisCivicAddressCache.Values
            }
        }
        else {
            if ($script:BulkAddressPopulatedDone) {
                return [LisCivicAddress[]]$LisCivicAddressCachePopulated.Values
            }
        }
        if ($PSCmdlet.ParameterSetName.EndsWith('Populate')) {
            $null = $PSBoundParameters.Remove('Populate')
            $PSBoundParameters['PopulateNumberOfVoiceUsers'] = $true
            $PSBoundParameters['PopulateNumberOfTelephoneNumbers'] = $true
        }

        $found = $false
        Get-CsOnlineLisCivicAddress @PSBoundParameters | ForEach-Object {
            $found = $true
            if ($null -eq $_) { return }
            $obj = [LisCivicAddress]$_
            $existing = $null
            if (($obj.NumberOfTelephoneNumbers -gt -1 -or $obj.NumberOfVoiceUsers -gt -1) -and $LisCivicAddressCache.TryGetValue($obj.CivicAddressId, [ref] $existing)) {
                $existing.NumberOfTelephoneNumbers = $obj.NumberOfTelephoneNumbers
                $existing.NumberOfVoiceUsers = $obj.NumberOfVoiceUsers
                $obj = $existing
            }
            else {
                $LisCivicAddressCache[$obj.CivicAddressId] = $obj
            }
            if ($obj.NumberOfTelephoneNumbers -gt -1 -and $obj.NumberOfVoiceUsers -gt -1) {
                $LisCivicAddressCachePopulated[$obj.CivicAddressId] = $obj
            }
            $obj
        }
        if (!$found -and $PSCmdlet.ParameterSetName -in @('Point', 'PointPopulate')) {
            $null = $Missing.Add($CivicAddressId)
        }
        $script:BulkAddressPopulatedDone = $BulkAddressPopulatedDone -or ($PSCmdlet.ParameterSetName -eq 'BulkPopulate' -and $found -and $LisCivicAddressCachePopulated.Count -eq $LisCivicAddressCache.Count)
        $script:BulkAddressDone = $BulkAddressDone -or ($PSCmdlet.ParameterSetName.StartsWith('Bulk') -and $found)
    }
}

function Get-CsOnlineLisLocationInternal {
    [CmdletBinding(DefaultParameterSetName = 'Bulk')]
    [OutputType([LisLocation])]
    param (
        [Parameter(ParameterSetName = 'Bulk')]
        [Parameter(ParameterSetName = 'BulkPopulate')]
        [string]
        $CivicAddressId,

        [Parameter(Mandatory, ParameterSetName = 'Point')]
        [Parameter(Mandatory, ParameterSetName = 'PointPopulate')]
        [string]
        $LocationId,

        [Parameter(Mandatory, ParameterSetName = 'PointPopulate')]
        [Parameter(Mandatory, ParameterSetName = 'BulkPopulate')]
        [switch]
        $Populate
    )
    end {
        if ($null -eq $script:Missing) { $script:Missing = [HashSet[string]]::new([StringComparer]::InvariantCultureIgnoreCase) }
        if ($null -eq $script:LisLocationCache) { $script:LisLocationCache = [Dictionary[string, LisLocation]]::new([StringComparer]::InvariantCultureIgnoreCase) }
        if ($null -eq $script:LisLocationCachePopulated) { $script:LisLocationCachePopulated = [Dictionary[string, LisLocation]]::new([StringComparer]::InvariantCultureIgnoreCase) }
        if ($null -eq $script:LisLocationByCivicAddressCache) { $script:LisLocationByCivicAddressCache = [HashSet[string]]::new([StringComparer]::InvariantCultureIgnoreCase) }
        if ($null -eq $script:LisLocationByCivicAddressCachePopulated) { $script:LisLocationByCivicAddressCachePopulated = [HashSet[string]]::new([StringComparer]::InvariantCultureIgnoreCase) }
        if ($PSCmdlet.ParameterSetName -eq 'Point') {
            if ($Missing.Contains($LocationId)) { return $null }
            $existing = $null
            if ($LisLocationCache.TryGetValue($LocationId, [ref] $existing)) {
                return $existing
            }
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'PointPopulate') {
            if ($Missing.Contains($LocationId)) { return $null }
            $existing = $null
            if ($LisLocationCachePopulated.TryGetValue($LocationId, [ref] $existing)) {
                return $existing
            }
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'Bulk') {
            if ($script:BulkLocationDone) {
                if ($PSBoundParameters.ContainsKey('CivicAddressId')) {
                    if ($Missing.Contains($CivicAddressId)) { return $null }
                    if ($LisLocationByCivicAddressCache.Contains($CivicAddressId)) {
                        return [LisLocation[]]$LisLocationCache.Values.Where({ $_.CivicAddressId -eq $CivicAddressId })
                    }
                }
                else {
                    return [LisLocation[]]$LisLocationCache.Values
                }
            }
        }
        else {
            if ($script:BulkLocationPopulatedDone) {
                if ($PSBoundParameters.ContainsKey('CivicAddressId')) { 
                    if ($Missing.Contains($CivicAddressId)) { return $null }
                    if ($LisLocationByCivicAddressCachePopulated.Contains($CivicAddressId)) {
                        return [LisLocation[]]$LisLocationCachePopulated.Values.Where({ $_.CivicAddressId -eq $CivicAddressId })
                    }
                }
                else {
                    return [LisLocation[]]$LisLocationCachePopulated.Values
                }
            }
        }
        if ($PSCmdlet.ParameterSetName.EndsWith('Populate')) {
            $null = $PSBoundParameters.Remove('Populate')
            $PSBoundParameters['PopulateNumberOfVoiceUsers'] = $true
            $PSBoundParameters['PopulateNumberOfTelephoneNumbers'] = $true
        }
        $found = $false
        Get-CsOnlineLisLocation @PSBoundParameters | ForEach-Object {
            $found = $true
            $obj = [LisLocation]$_
            if ($null -eq $obj) { return }
            $existing = $null
            if (($obj.NumberOfTelephoneNumbers -gt -1 -or $obj.NumberOfVoiceUsers -gt -1) -and $LisLocationCache.TryGetValue($obj.LocationId, [ref] $existing)) {
                $existing.NumberOfTelephoneNumbers = $obj.NumberOfTelephoneNumbers
                $existing.NumberOfVoiceUsers = $obj.NumberOfVoiceUsers
                $obj = $existing
            }
            $LisLocationCache[$obj.LocationId] = $obj
            if ($obj.NumberOfTelephoneNumbers -gt -1 -and $obj.NumberOfVoiceUsers -gt -1) {
                $LisLocationCachePopulated[$obj.LocationId] = $obj
            }
            if ($PSCmdlet.ParameterSetName.StartsWith('Bulk')) {
                $null = $LisLocationByCivicAddressCache.Add($obj.CivicAddressId)
                if ($PSCmdlet.ParameterSetName.EndsWith('Populate')) {
                    $null = $LisLocationByCivicAddressCachePopulated.Add($obj.CivicAddressId)
                }
            }
            $obj
        }
        if (!$found -and $PSCmdlet.ParameterSetName -in @('Point', 'PointPopulate')) {
            $null = $Missing.Add($LocationId)
        }
        $script:BulkLocationPopulatedDone = $BulkLocationPopulatedDone -or ($PSCmdlet.ParameterSetName -eq 'BulkPopulate' -and !$PSBoundParameters.ContainsKey('CivicAddressId') -and $found -and $LisLocationCachePopulated.Count -eq $LisLocationCache.Count)
        $script:BulkLocationDone = $BulkLocationDone -or ($PSCmdlet.ParameterSetName.StartsWith('Bulk') -and !$PSBoundParameters.ContainsKey('CivicAddressId') -and $found)
    }
}

function Get-CsOnlineLisPortInternal {
    [CmdletBinding(DefaultParameterSetName = 'Bulk')]
    [OutputType([LisPort])]
    param (
        [Parameter(Mandatory, ParameterSetName = 'Point')]
        [string]
        $ChassisId,

        [Parameter(Mandatory, ParameterSetName = 'Point')]
        [string]
        $PortId,

        [Parameter(Mandatory, ParameterSetName = 'BulkLocation')]
        [string]
        $LocationId
    )
    end {
        if ($null -eq $script:Missing) { $script:Missing = [HashSet[string]]::new([StringComparer]::InvariantCultureIgnoreCase) }
        if ($null -eq $script:LisPortCache) { $script:LisPortCache = [Dictionary[string, LisPort]]::new([StringComparer]::InvariantCultureIgnoreCase) }
        if ($null -eq $script:LisPortByLocationCache) { $script:LisPortByLocationCache = [Dictionary[string, Dictionary[string, LisPort]]]::new([StringComparer]::InvariantCultureIgnoreCase) }
        if ($PSCmdlet.ParameterSetName -eq 'Point') {
            $ID = $ChassisId + ';' + $PortId
            if ($Missing.Contains($ID)) { return $null }
            $existing = $null
            if ($LisPortCache.TryGetValue($ID, [ref] $existing)) {
                return $existing
            }
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'BulkLocation') {
            $existing = $null
            if ($script:BulkPortDone -and $LisPortByLocationCache.TryGetValue($LocationId, [ref] $existing)) {
                return [LisPort[]]$existing.Values
            }
            if ($script:BulkPortDone) { return $null }
            $null = $PSBoundParameters.Remove('LocationId')
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'Bulk') {
            if ($script:BulkPortDone) {
                return [LisPort[]]$LisPortCache.Values
            }
        }
        $found = $false
        Get-CsOnlineLisPort @PSBoundParameters | ForEach-Object {
            $found = $true
            $obj = [LisPort]$_
            if ($null -eq $obj) { return }
            $ID = $obj.ChassisId + ';' + $obj.PortId
            $LisPortCache[$ID] = $obj
            $locationLookup = $null
            $lId = $obj.LocationId.ToString()
            if (!$LisPortByLocationCache.TryGetValue($lId, [ref] $locationLookup)) {
                $locationLookup = [Dictionary[string, LisPort]]::new([StringComparer]::InvariantCultureIgnoreCase)
                $LisPortByLocationCache[$lId] = $locationLookup
            }
            $locationLookup[$ID] = $obj
            if ($PSCmdlet.ParameterSetName -eq 'BulkLocation') {
                if ($lId -eq $LocationId) {
                    $obj
                }
                return
            }
            $obj
        }
        if (!$found -and $PSCmdlet.ParameterSetName -eq 'Point') {
            $ID = $ChassisId + ';' + $PortId
            $null = $Missing.Add($ID)
        }
        $script:BulkPortDone = $script:BulkPortDone -or $PSCmdlet.ParameterSetName -ne 'Point'
    }
}

function Get-CsOnlineLisSwitchInternal {
    [CmdletBinding(DefaultParameterSetName = 'Bulk')]
    [OutputType([LisSwitch])]
    param (
        [Parameter(Mandatory, ParameterSetName = 'Point')]
        [string]
        $ChassisId,

        [Parameter(Mandatory, ParameterSetName = 'BulkLocation')]
        [string]
        $LocationId
    )
    end {
        if ($null -eq $script:Missing) { $script:Missing = [HashSet[string]]::new([StringComparer]::InvariantCultureIgnoreCase) }
        if ($null -eq $script:LisSwitchCache) { $script:LisSwitchCache = [Dictionary[string, LisSwitch]]::new([StringComparer]::InvariantCultureIgnoreCase) }
        if ($null -eq $script:LisSwitchByLocationCache) { $script:LisSwitchByLocationCache = [Dictionary[string, Dictionary[string, LisSwitch]]]::new([StringComparer]::InvariantCultureIgnoreCase) }
        if ($PSCmdlet.ParameterSetName -eq 'Point') {
            if ($Missing.Contains($ChassisId)) { return $null }
            $existing = $null
            if ($LisSwitchCache.TryGetValue($ChassisId, [ref] $existing)) {
                return $existing
            }
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'BulkLocation') {
            $existing = $null
            if ($script:BulkSwitchDone -and $LisSwitchByLocationCache.TryGetValue($LocationId, [ref] $existing)) {
                return [LisSwitch[]]$existing.Values
            }
            if ($script:BulkSwitchDone) { return $null }
            $null = $PSBoundParameters.Remove('LocationId')
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'Bulk') {
            if ($script:BulkSwitchDone) {
                return [LisSwitch[]]$LisSwitchCache.Values
            }
        }
        $found = $false
        Get-CsOnlineLisSwitch @PSBoundParameters | ForEach-Object {
            $found = $true
            $obj = [LisSwitch]$_
            if ($null -eq $obj) { return }
            $LisSwitchCache[$obj.ChassisId] = $obj
            $locationLookup = $null
            $lId = $obj.LocationId.ToString()
            if (!$LisSwitchByLocationCache.TryGetValue($lId, [ref] $locationLookup)) {
                $locationLookup = [Dictionary[string, LisSwitch]]::new([StringComparer]::InvariantCultureIgnoreCase)
                $LisSwitchByLocationCache[$lId] = $locationLookup
            }
            $locationLookup[$obj.ChassisId] = $obj
            if ($PSCmdlet.ParameterSetName -eq 'BulkLocation') {
                if ($lId -eq $LocationId) {
                    $obj
                }
                return
            }
            $obj
        }
        if (!$found -and $PSCmdlet.ParameterSetName -eq 'Point') {
            $null = $Missing.Add($ChassisId)
        }
        $script:BulkSwitchDone = $script:BulkSwitchDone -or $PSCmdlet.ParameterSetName -ne 'Point'
    }
}

function Get-CsOnlineLisSubnetInternal {
    [CmdletBinding(DefaultParameterSetName = 'Bulk')]
    [OutputType([LisSubnet])]
    param (
        [Parameter(Mandatory, ParameterSetName = 'Point')]
        [string]
        $Subnet,

        [Parameter(Mandatory, ParameterSetName = 'BulkLocation')]
        [string]
        $LocationId
    )
    end {
        if ($null -eq $script:Missing) { $script:Missing = [HashSet[string]]::new([StringComparer]::InvariantCultureIgnoreCase) }
        if ($null -eq $script:LisSubnetCache) { $script:LisSubnetCache = [Dictionary[string, LisSubnet]]::new([StringComparer]::InvariantCultureIgnoreCase) }
        if ($null -eq $script:LisSubnetByLocationCache) { $script:LisSubnetByLocationCache = [Dictionary[string, Dictionary[string, LisSubnet]]]::new([StringComparer]::InvariantCultureIgnoreCase) }
        if ($PSCmdlet.ParameterSetName -eq 'Point') {
            if ($Missing.Contains($Subnet)) { return $null }
            $existing = $null
            if ($LisSubnetCache.TryGetValue($Subnet, [ref] $existing)) {
                return $existing
            }
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'BulkLocation') {
            $existing = $null
            if ($script:BulkSubnetDone -and $LisSubnetByLocationCache.TryGetValue($LocationId, [ref] $existing)) {
                return [LisSubnet[]]$existing.Values
            }
            if ($script:BulkSubnetDone) { return $null }
            $null = $PSBoundParameters.Remove('LocationId')
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'Bulk') {
            if ($script:BulkSubnetDone) {
                return [LisSubnet[]]$LisSubnetCache.Values
            }
        }
        $found = $false
        Get-CsOnlineLisSubnet @PSBoundParameters | ForEach-Object {
            $found = $true
            $obj = [LisSubnet]$_
            if ($null -eq $obj) { return }
            $LisSubnetCache[$obj.Subnet] = $obj
            $locationLookup = $null
            $lId = $obj.LocationId.ToString()
            if (!$LisSubnetByLocationCache.TryGetValue($lId, [ref] $locationLookup)) {
                $locationLookup = [Dictionary[string, LisSubnet]]::new([StringComparer]::InvariantCultureIgnoreCase)
                $LisSubnetByLocationCache[$lId] = $locationLookup
            }
            $locationLookup[$obj.Subnet] = $obj
            if ($PSCmdlet.ParameterSetName -eq 'BulkLocation') {
                if ($lId -eq $LocationId) {
                    $obj
                }
                return
            }
            $obj
        }
        if (!$found -and $PSCmdlet.ParameterSetName -eq 'Point') {
            $null = $Missing.Add($Subnet)
        }
        $script:BulkSubnetDone = $script:BulkSubnetDone -or $PSCmdlet.ParameterSetName -ne 'Point'
    }
}

function Get-CsOnlineLisWirelessAccessPointInternal {
    [CmdletBinding(DefaultParameterSetName = 'Bulk')]
    [OutputType([LisWirelessAccessPoint])]
    param (
        [Parameter(Mandatory, ParameterSetName = 'Point')]
        [string]
        $BSSID,

        [Parameter(Mandatory, ParameterSetName = 'BulkLocation')]
        [string]
        $LocationId
    )
    end {
        if ($null -eq $script:Missing) { $script:Missing = [HashSet[string]]::new([StringComparer]::InvariantCultureIgnoreCase) }
        if ($null -eq $script:LisWirelessAccessPointCache) { $script:LisWirelessAccessPointCache = [Dictionary[string, LisWirelessAccessPoint]]::new([StringComparer]::InvariantCultureIgnoreCase) }
        if ($null -eq $script:LisWirelessAccessPointByLocationCache) { $script:LisWirelessAccessPointByLocationCache = [Dictionary[string, Dictionary[string, LisWirelessAccessPoint]]]::new([StringComparer]::InvariantCultureIgnoreCase) }
        if ($PSCmdlet.ParameterSetName -eq 'Point') {
            if ($Missing.Contains($BSSID)) { return $null }
            $existing = $null
            if ($LisWirelessAccessPointCache.TryGetValue($BSSID, [ref] $existing)) {
                return $existing
            }
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'BulkLocation') {
            $existing = $null
            if ($script:BulkWirelessAccessPointDone -and $LisWirelessAccessPointByLocationCache.TryGetValue($LocationId, [ref] $existing)) {
                return [LisWirelessAccessPoint[]]$existing.Values
            }
            if ($script:BulkWirelessAccessPointDone) { return $null }
            $null = $PSBoundParameters.Remove('LocationId')
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'Bulk') {
            if ($script:BulkWirelessAccessPointDone) {
                return [LisWirelessAccessPoint[]]$LisWirelessAccessPointCache.Values
            }
        }
        $found = $false
        Get-CsOnlineLisWirelessAccessPoint @PSBoundParameters | ForEach-Object {
            $found = $true
            $obj = [LisWirelessAccessPoint]$_
            if ($null -eq $obj) { return }
            $LisWirelessAccessPointCache[$obj.BSSID] = $obj
            $locationLookup = $null
            $lId = $obj.LocationId.ToString()
            if (!$LisWirelessAccessPointByLocationCache.TryGetValue($lId, [ref] $locationLookup)) {
                $locationLookup = [Dictionary[string, LisWirelessAccessPoint]]::new([StringComparer]::InvariantCultureIgnoreCase)
                $LisWirelessAccessPointByLocationCache[$lId] = $locationLookup
            }
            $locationLookup[$obj.BSSID] = $obj
            if ($PSCmdlet.ParameterSetName -eq 'BulkLocation') {
                if ($lId -eq $LocationId) {
                    $obj
                }
                return
            }
            $obj
        }
        if (!$found -and $PSCmdlet.ParameterSetName -eq 'Point') {
            $null = $Missing.Add($BSSID)
        }
        $script:BulkWirelessAccessPointDone = $script:BulkWirelessAccessPointDone -or $PSCmdlet.ParameterSetName -ne 'Point'
    }
}
