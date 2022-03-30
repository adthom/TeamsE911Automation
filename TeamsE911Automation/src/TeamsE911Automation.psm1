
# (imported from .\classes\ChangeObject.ps1)
class ChangeObject {
    hidden [string] $_hash
    hidden [CommandType] $CommandType
    hidden [object] $CommandObject
    hidden [void] Init([PSCustomObject] $obj) {
        if ($obj.CommandObject) {
            $this.CommandObject = $obj.CommandObject
            $this.Id = [ItemId]::new($obj.CommandObject.Id)
        }
        if ($null -eq $this.Id -and $null -ne $obj.Id) {
            $this.Id = [ItemId]::new($obj.Id)
        }
        if ($null -eq $this.Id) {
            $this.Id = [ItemId]::new()
        }
        $this.UpdateType = [UpdateType]$obj.UpdateType
        if ($this.UpdateType -eq [UpdateType]::Source) {
            $this.ProcessInfo = [E911DataRow]$obj.ProcessInfo
        }
        if ($this.UpdateType -eq [UpdateType]::Online) {
            $this.ProcessInfo = if ($obj.ProcessInfo -is [string]) { [ScriptBlock]::Create($obj.ProcessInfo) } else { $obj.ProcessInfo }
        }
        if ($obj.CommandType) {
            $this.CommandType = $obj.CommandType
        }
        $d = $obj.DependsOn
        if ($null -eq $d) {
            $d = [DependsOn]::new()
        }
        $this.DependsOn = [DependsOn]::new($d)
    }
    ChangeObject([E911DataRow] $row) {
        $this.Init([PSCustomObject]@{
                Id            = $row.Id
                UpdateType    = [UpdateType]::Source
                ProcessInfo   = $row
                CommandObject = $row
                DependsOn     = [DependsOn]::new()
            })
    }
    ChangeObject([E911DataRow] $row, [DependsOn] $deps) {
        $this.Init([PSCustomObject]@{
                Id            = $row.Id
                UpdateType    = [UpdateType]::Source
                ProcessInfo   = $row
                CommandObject = $row
                DependsOn     = [DependsOn]::new($deps)
            })
    }
    ChangeObject([PSCustomObject] $obj) {
        $this.Init($obj)
    }
    ChangeObject([Hashtable] $obj) {
        $this.Init([PSCustomObject]$obj)
    }
    [ItemId] $Id
    [UpdateType] $UpdateType
    [object] $ProcessInfo
    [DependsOn] $DependsOn

    [string] GetHash() {
        if ([string]::IsNullOrEmpty($this._hash) -and $null -ne $this.ProcessInfo) {
            $this._hash = [Hasher]::GetHash($this.ProcessInfo.ToString())
        }
        return $this._hash
    }

    [bool] Equals($Value) {
        if ($null -eq $Value) {
            return $false
        }
        return $this.GetHash() -eq $Value.GetHash()
    }
}

# (imported from .\classes\CommandType.ps1)
enum CommandType {
    Default
    Address
    GetAddress
    Location
    NetworkObject
}

# (imported from .\classes\DependsOn.ps1)
class DependsOn {
    hidden [System.Collections.Generic.List[ItemId]] $_items
    DependsOn() {
        $this._items = [System.Collections.Generic.List[ItemId]]::new()
    }
    DependsOn([string] $DependsOnString) {
        $this._items = [System.Collections.Generic.List[ItemId]]::new()
        if ([string]::IsNullOrEmpty($DependsOnString)) {
            return
        }
        $Parts = $DependsOnString.Split(';')
        foreach ($Part in $Parts) {
            $this.Add([ItemId]::new($Part.Trim()))
        }
    }
    [void] Clear() {
        $this._items.Clear()
    }
    [bool] Contains([ItemId] $Id) {
        return $this._items.Contains($Id)
    }
    [int] Count() {
        return $this._items.Count
    }
    [void] Add([ItemId] $Id) {
        if ($this._items.Contains($Id)) { return }
        $this._items.Add($Id)
    }
    [void] AddRange([System.Collections.Generic.IEnumerable[ItemId]] $Ids) {
        foreach ($Id in $Ids) {
            $this.Add($Id)
        }
    }
    [void] AddRange([DependsOn] $DependsOn) {
        foreach ($Id in $DependsOn.GetEnumerator()) {
            $this.Add($Id)
        }
    }
    [void] AddAsString([string] $Id) {
        $this.Add([ItemId]::new($Id))
    }
    [void] Remove([ItemId] $Id) {
        $this._items.Remove($Id)
    }
    [void] Insert([int]$Position, [ItemId] $Id) {
        $this._items.Insert($Position, $Id)
    }
    [System.Collections.IEnumerator] GetEnumerator() {
        return $this._items.GetEnumerator()
    }
    [System.Collections.IEnumerator] GetEnumerator([int] $Index, [int] $Count) {
        return $this._items.GetEnumerator($Index, $Count)
    }
    [string] ToString() {
        return ($this._items -join ';')
    }
}

# (imported from .\classes\E911Address.ps1)
class E911Address {
    hidden static [string[]] $_addressHashProps = @("CompanyName", "Address", "City", "StateOrProvince", "PostalCode", "CountryOrRegion")

    hidden [ItemId] $Id
    hidden [string] $_houseNumber
    hidden [string] $_streetName
    hidden [string] $_hash
    hidden [string] $_command
    hidden [string] $DefaultLocationId
    hidden [bool] $_isOnline
    hidden [bool] $_hasChanged

    hidden [void] Init([PSCustomObject] $obj, [bool]$ShouldValidate) {
        if (![string]::IsNullOrEmpty($obj.CivicAddressId)) {
            $this.Id = [ItemId]::new($obj.CivicAddressId)
        }
        else {
            $this.Id = [ItemId]::new()
        }
        $this.Warning = [WarningList]::new()
        $WarnType = [WarningType]::InvalidInput

        $addr = [E911Address]::_convertOnlineAddress($obj)
        $this._isOnline = $true
        $this._hasChanged = $false
        if ([string]::IsNullOrEmpty($addr)) {
            $addr = $obj.Address
            $this._isOnline = $false
        }
        $this.SkipMapsLookup = $this._isOnline -and $obj.Latitude -ne 0.0 -and $obj.Longitude -ne 0.0 # don't validate an online object that already has geocodes
        if ($ShouldValidate) {
            if ([string]::IsNullOrEmpty($addr)) {
                $this.Warning.Add($WarnType, 'Address missing')
            }
            # all required
            $RequiredProps = @(
                "CompanyName",
                "City",
                "StateOrProvince",
                "CountryOrRegion"
            )
            try {
                $this.SkipMapsLookup = ![string]::IsNullOrWhiteSpace($obj.SkipMapsLookup) -and [System.Convert]::ToBoolean($obj.SkipMapsLookup)
            }
            catch {
                [void]$this.Warning.Add($WarnType, "SkipMapsLookup '$($obj.SkipMapsLookup)'")
            }
            if ($this.SkipMapsLookup) {
                # add required if skipping lookup
                $RequiredProps += "PostalCode"
                $RequiredProps += "Latitude"
                $RequiredProps += "Longitude"
            }
            foreach ($Required in $RequiredProps) {
                if ([string]::IsNullOrWhiteSpace($obj.$Required)) {
                    [void]$this.Warning.Add($WarnType, "$Required missing")
                }
            }
            if ($obj.CountryOrRegion.Length -ne 2) {
                [void]$this.Warning.Add($WarnType, "CountryOrRegion not ISO 3166-1 alpha-2 code")
            }
            if (![string]::IsNullOrEmpty($obj.Longitude) -xor ![string]::IsNullOrEmpty($obj.Latitude)) {
                # only one provided of lat or long, both are required if either is present
                [void]$this.Warning.Add($WarnType, "Missing $(if([string]::IsNullOrEmpty($obj.Latitude)) { "Latitude" } else { "Longitude" })")

            }
            if ($this.SkipMapsLookup -or ![string]::IsNullOrEmpty($obj.Latitude) -or ![string]::IsNullOrEmpty($obj.Longitude)) {
                $long = $null
                $lat = $null
                if (![double]::TryParse($obj.Longitude, [ref] $long) -or ($long -gt 180.0 -or $long -lt -180.0)) {
                    [void]$this.Warning.Add($WarnType, "Longitude '$($obj.Latitude)'")
                }
                if (![double]::TryParse($obj.Latitude, [ref] $lat) -or ($lat -gt 90.0 -or $lat -lt -90.0)) {
                    [void]$this.Warning.Add($WarnType, "Latitude '$($obj.Latitude)'")
                }
            }
        }

        $this.CompanyName = $obj.CompanyName
        $this.CompanyTaxId = $obj.CompanyTaxId
        $this.Description = $obj.Description
        $this.Address = $addr -replace '\s+', ' '
        $this.City = $obj.City
        $this.CountryOrRegion = $obj.CountryOrRegion
        $this.StateOrProvince = $obj.StateOrProvince
        $this.PostalCode = $obj.PostalCode
        $this.Latitude = $obj.Latitude
        $this.Longitude = $obj.Longitude
        $this.DefaultLocationId = $obj.DefaultLocationId
        if (![string]::IsNullOrEmpty($obj.Elin) -and [string]::IsNullOrEmpty($obj.Location)) {
            $this.Elin = $obj.Elin
        }

        if ($ShouldValidate -and !$this.SkipMapsLookup) {
            [E911ModuleState]::ValidateAddress($this)
        }
    }

    E911Address ([PSCustomObject] $obj, [bool]$ShouldValidate) {
        $this.Init($obj, $ShouldValidate)
    }

    hidden E911Address() {}

    # Public Properties
    [string] $CompanyName

    [AllowEmptyString()]
    [string] $CompanyTaxId

    [AllowEmptyString()]
    [string] $Description

    [string] $Address

    [string] $City

    [string] $StateOrProvince

    [AllowEmptyString()]
    [string] $PostalCode

    [string] $CountryOrRegion

    [AllowNull()]
    [ValidateRange(-90.0, 90.0)]
    [double] $Latitude

    [AllowNull()]
    [ValidateRange(-180.0, 180.0)]
    [double] $Longitude

    [AllowEmptyString()]
    [string] $Elin

    [bool]
    $SkipMapsLookup

    [WarningList] $Warning

    [string] HouseNumber() {
        if ([string]::IsNullOrEmpty($this._houseNumber) -and [string]::IsNullOrEmpty($this._streetName)) {
            if ([string]::IsNullOrEmpty($this.Address)) {
                return [string]::Empty
            }
            $this._houseNumber = ($this.Address -replace '^.*?(\d+\S*)\s+.*$', '$1').Trim()
        }
        return $this._houseNumber
    }

    [string] StreetName() {
        if ([string]::IsNullOrEmpty($this._streetName)) {
            if ([string]::IsNullOrEmpty($this.Address)) {
                return [string]::Empty
            }
            $this._streetName = ($this.Address -replace [regex]::Escape($this.HouseNumber()), '').Trim()
            if ([string]::IsNullOrEmpty($this._streetName) -and ![string]::IsNullOrEmpty($this._houseNumber)) {
                $this._streetName = $this._houseNumber
                $this._houseNumber = ''
            }
        }
        return $this._streetName
    }

    [bool] HasWarnings() {
        return $null -ne $this.Warning -and $this.Warning.HasWarnings()
    }

    [bool] ValidationFailed() {
        return $this.Warning.ValidationFailed()
    }

    [int] ValidationFailureCount() {
        return $this.Warning.ValidationFailureCount()
    }

    [string] GetDefaultLocationCommand() {
        return '{0} = Get-CsOnlineLisCivicAddress -ErrorAction Stop -CivicAddressId "{1}"' -f $this.Id.VariableName(), $this.Id.ToString()
    }

    [string] GetCommand() {
        if ([string]::IsNullOrEmpty($this._command) -and $this._hasChanged) {
            $sb = [Text.StringBuilder]::new()
            $AddressParams = @{
                StreetName      = $this.StreetName()
                City            = $this.City
                StateOrProvince = $this.StateOrProvince
                CompanyName     = $this.CompanyName
            }
            if (![string]::IsNullOrEmpty($this.HouseNumber())) {
                $AddressParams['HouseNumber'] = $this.HouseNumber()
            }
            if (![string]::IsNullOrEmpty($this.Description)) {
                $AddressParams['Description'] = $this.Description
            }
            if (![string]::IsNullOrEmpty($this.CompanyTaxId)) {
                $AddressParams['CompanyTaxId'] = $this.CompanyTaxId
            }
            if (![string]::IsNullOrEmpty($this.PostalCode)) {
                $AddressParams['PostalCode'] = $this.PostalCode
            }
            if (![string]::IsNullOrEmpty($this.CountryOrRegion)) {
                $AddressParams['Country'] = $this.CountryOrRegion
            }
            if (![string]::IsNullOrEmpty($this.Latitude) -and ![string]::IsNullOrEmpty($this.Longitude)) {
                $AddressParams['Latitude'] = $this.Latitude
                $AddressParams['Longitude'] = $this.Longitude
            }
            if (![string]::IsNullOrEmpty($this.Elin)) {
                $AddressParams['Elin'] = $this.Elin
            }
            [void]$sb.AppendFormat("{0} = New-CsOnlineLisCivicAddress -ErrorAction Stop", $this.Id.VariableName())
            foreach ($Parameter in $AddressParams.Keys) {
                [void]$sb.AppendFormat(' -{0} "{1}"', $Parameter, $AddressParams[$Parameter])
            }
            $this._command = $sb.ToString()
        }
        return $this._command
    }

    static [string] GetHash([PSCustomObject] $obj) {
        $addr = [E911Address]::_convertOnlineAddress($obj)
        if ([string]::IsNullOrEmpty($addr)) {
            $addr = $obj.Address
        }
        $test = [PSCustomObject]@{
            CompanyName     = $obj.CompanyName
            Address         = $addr -replace '\s+', ' '
            City            = $obj.City
            StateOrProvince = $obj.StateOrProvince
            PostalCode      = $obj.PostalCode
            CountryOrRegion = $obj.CountryOrRegion
        }
        $Hash = [Hasher]::GetHash(($test | Select-Object -Property ([E911Address]::_addressHashProps) | ConvertTo-Json -Compress).ToLower())
        return $Hash
    }

    [string] GetHash() {
        if ([string]::IsNullOrEmpty($this._hash)) {
            $this._hash = [Hasher]::GetHash(($this | Select-Object -Property ([E911Address]::_addressHashProps) | ConvertTo-Json -Compress).ToLower())
        }
        return $this._hash
    }

    static [bool] Equals($Value1, $Value2) {
        if ($null -eq $Value1 -and $null -eq $Value2) {
            return $true
        }
        if ($null -eq $Value1 -or $null -eq $Value2) {
            return $false
        }
        if ([E911Address]::GetHash($Value1) -ne [E911Address]::GetHash($Value2)) {
            return $false
        }
        if ([string]::IsNullOrEmpty($Value1.Location) -and [string]::IsNullOrEmpty($Value2.Location)) {
            # if this is a default location, compare elin values
            if ($Value1.Elin -ne $Value2.Elin) {
                return $false
            }
        }
        if ([string]::IsNullOrEmpty($Value1.CivicAddressId) -or [string]::IsNullOrEmpty($Value2.CivicAddressId)) {
            # don't compare descriptions if we have an online location object
            return $true
        }
        if ($Value1.DefaultLocationId -ne $Value2.DefaultLocationId) {
            return $false
        }
        $D1 = if ([string]::IsNullOrEmpty($Value1.Description)) { '' } else { $Value1.Description }
        $D2 = if ([string]::IsNullOrEmpty($Value2.Description)) { '' } else { $Value2.Description }
        return $D1 -eq $D2
    }

    [bool] Equals($Value) {
        if ($null -eq $Value) {
            return $false
        }
        if ($Value -isnot [E911Address]) {
            return $false
        }
        if ($this.GetHash() -ne $Value.GetHash()) {
            return $false
        }
        return $this.Description -eq $Value.Description -and $this.Elin -eq $Value.Elin
    }

    hidden static [string] _convertOnlineAddress([PSCustomObject]$Online) {
        if ($Online -is [E911Address] -or $Online -is [E911Location]) {
            return ''
        }
        $AddressKeys = @(
            "HouseNumber",
            "HouseNumberSuffix",
            "PreDirectional",
            "StreetName",
            "StreetSuffix",
            "PostDirectional"
        )
        $addressSb = [Text.StringBuilder]::new()
        foreach ($prop in $AddressKeys) {
            if (![string]::IsNullOrEmpty($Online.$prop)) {
                if ($addressSb.Length -gt 0) {
                    $addressSb.Append(' ') | Out-Null
                }
                $addressSb.Append($Online.$prop.Trim()) | Out-Null
            }
        }
        return $addressSb.ToString()
    }
}

# (imported from .\classes\E911DataRow.ps1)
class E911DataRow {
    hidden static [object[]] $Properties = @('CompanyName','CompanyTaxId','Description','Address','Location','City','StateOrProvince','PostalCode','CountryOrRegion','Latitude','Longitude','Elin','NetworkDescription','NetworkObjectType','NetworkObjectIdentifier','SkipMapsLookup')
    # Hidden Properties
    hidden [PSCustomObject] $_originalRow
    hidden [string] $_string
    hidden [string] $_hashString
    hidden [string] $_hash
    hidden [string] $_rowName
    hidden [int] $_lastWarnCount
    hidden [E911NetworkObject] $_networkObject
    hidden [ItemId] $Id = [ItemId]::new()

    # Constructors
    hidden [void] Init([PSCustomObject] $obj) {
        $this._originalRow = $obj
        $this.Warning = [WarningList]::new($obj.Warning)

        $ShouldValidate = $this.HasChanged()
        if (!$ShouldValidate) {
            $this.Warning.Clear()
        }

        $this._AddCompanyName()
        $this._AddCompanyTaxId()
        $this._AddDescription()
        $this._AddAddress()
        $this._AddLocation()
        $this._AddCity()
        $this._AddStateOrProvince()
        $this._AddPostalCode()
        $this._AddCountryOrRegion()
        $this._AddLatitude()
        $this._AddLongitude()
        $this._AddELIN()
        $this._AddNetworkDescription()
        $this._AddNetworkObjectType()
        $this._AddNetworkObjectIdentifier()
        $this._AddEntryHash()

        if ($null -eq $obj) {
            return
        }
        $WarnType = [WarningType]::InvalidInput

        try {
            $this._networkObject = [E911ModuleState]::GetOrCreateNetworkObject($obj, $ShouldValidate)
        }
        catch {
            $this.Warning.Add($WarnType, "NetworkObject Creation Failed: $($_.Exception.Message)")
        }
        if ($null -ne $this._networkObject.Warning -and $this._networkObject.Warning.HasWarnings()) {
            $this.Warning.AddRange($this._networkObject.Warning)
        }
    }

    E911DataRow() {
        $this.Init($null)
    }

    E911DataRow([PSCustomObject]$obj) {
        $this.Init($obj)
    }

    E911DataRow([E911NetworkObject] $nObj) {
        $this.Warning = [WarningList]::new($nObj.Warning)
        $this._networkObject = $nObj
        $this.SkipMapsLookup = $nObj._isOnline -and $this.Longitude -ne 0.0 -and $this.Latitude -ne 0.0

        $this._AddCompanyName()
        $this._AddCompanyTaxId()
        $this._AddDescription()
        $this._AddAddress()
        $this._AddLocation()
        $this._AddCity()
        $this._AddStateOrProvince()
        $this._AddPostalCode()
        $this._AddCountryOrRegion()
        $this._AddLatitude()
        $this._AddLongitude()
        $this._AddELIN()
        $this._AddNetworkDescription()
        $this._AddNetworkObjectType()
        $this._AddNetworkObjectIdentifier()
        $this._AddEntryHash()

        $this._originalRow = [PSCustomObject]@{
            CompanyName             = "$($this.CompanyName)"
            CompanyTaxId            = "$($this.CompanyTaxId)"
            Description             = "$($this.Description)"
            Address                 = "$($this.Address)"
            Location                = "$($this.Location)"
            City                    = "$($this.City)"
            StateOrProvince         = "$($this.StateOrProvince)"
            PostalCode              = "$($this.PostalCode)"
            CountryOrRegion         = "$($this.CountryOrRegion)"
            Latitude                = "$($this.Latitude)"
            Longitude               = "$($this.Longitude)"
            Elin                    = "$($this.Elin)"
            NetworkDescription      = "$($this.NetworkDescription)"
            NetworkObjectType       = "$($this.NetworkObjectType)"
            NetworkObjectIdentifier = "$($this.NetworkObjectIdentifier.ToString())"
            SkipMapsLookup          = "$($this.SkipMapsLookup)"
        }
    }

    [bool] $SkipMapsLookup = $false

    [WarningList] $Warning

    # Public Methods
    [string] RowName() {
        if ([string]::IsNullOrEmpty($this._rowName)) {
            if ($null -eq $this._networkObject) {
                $this._networkObject = [E911NetworkObject]::new()
            }
            $this._rowName = @($this.CompanyName, $this.Address, $this.Location, $this.NetworkObjectType, $this.NetworkObjectIdentifier).Where({ ![string]::IsNullOrEmpty($_) }) -join ':'
        }
        return $this._rowName
    }

    [bool] HasChanged() {
        return $null -eq $this._originalRow.EntryHash -or $this._originalRow.EntryHash -ne $this.GetHash()
    }

    [bool] NeedsUpdate() {
        if ($null -eq $this._networkObject -or $null -eq $this._networkObject._location -or $null -eq $this._networkObject._location._address) {
            return $false
        }
        return !$this._networkObject._hasChanged -and !$this._networkObject._location._hasChanged -and !$this._networkObject._location._address._hasChanged
    }

    [bool] HasWarnings() {
        if ($null -ne $this._networkObject -and $this._networkObject.HasWarnings()) {
            $this.Warning.AddRange($this._networkObject.Warning)
        }
        return $null -ne $this.Warning -and $this.Warning.HasWarnings()
    }

    [bool] ValidationFailed() {
        if ($null -ne $this._networkObject -and $this._networkObject.ValidationFailed()) {
            $this.Warning.AddRange($this._networkObject.Warning)
        }
        return $this.Warning.ValidationFailed()
    }

    [int] ValidationFailureCount() {
        if ($null -ne $this._networkObject -and $this._networkObject.ValidationFailed()) {
            $this.Warning.AddRange($this._networkObject.Warning)
        }
        return $this.Warning.ValidationFailureCount()
    }

    [string] HouseNumber() {
        return $this._networkObject._location.HouseNumber()
    }

    [string] StreetName() {
        return $this._networkObject._location.StreetName()
    }

    [Collections.Generic.List[ChangeObject]] GetChangeCommands([Diagnostics.Stopwatch]$vsw) {
        $CommandName = [E911ModuleState]::GetCommandName()
        Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$CommandName] Getting Commands: $($this.RowName())..."

        $l = [Collections.Generic.List[ChangeObject]]::new()
        $GetCommands = $true
        if ((!$this.HasChanged() -and ![E911ModuleState]::ForceOnlineCheck)) {
            $GetCommands = $false
        }
        if ($null -eq $this._networkObject -or $null -eq $this._networkObject._location -or $null -eq $this._networkObject._location._address) {
            $this.Warning.Add([WarningType]::GeneralFailure, 'Row is missing network object, location, or address')
            $GetCommands = $false
        }
        $d = [DependsOn]::new()
        if ($GetCommands) {
            $ac = $this._networkObject._location._address.GetCommand()
            $NeedToGetAddress = $false
            $UseVariable = $false
            if (![string]::IsNullOrEmpty($ac)) {
                Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$CommandName] $($this.RowName()): Address new or changed!"
                $NeedToGetAddress = $this._location._isDefault
                $UseVariable = $true
                $l.Add([ChangeObject]@{
                        UpdateType    = [UpdateType]::Online
                        ProcessInfo   = $ac
                        DependsOn     = $d
                        CommandType   = [CommandType]::Address
                        CommandObject = $this._networkObject._location._address
                    })
                $d.Add($this._networkObject._location._address.Id)
            }
            $lc = $this._networkObject._location.GetCommand()
            if (![string]::IsNullOrEmpty($lc)) {
                Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$CommandName] $($this.RowName()): Location new or changed!"
                $UseVariable = $true
                $l.Add([ChangeObject]@{
                        UpdateType    = [UpdateType]::Online
                        ProcessInfo   = $lc
                        DependsOn     = $d
                        CommandType   = [CommandType]::Location
                        CommandObject = $this._networkObject._location
                    })
                $d.Add($this._networkObject._location.Id)
            }
            $nc = $this._networkObject.GetCommand($UseVariable)
            if (![string]::IsNullOrEmpty($nc)) {
                Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$CommandName] $($this.RowName()): Network Object new or changed!"
                if ($NeedToGetAddress) {
                    $gac = $this._networkObject._location._address.GetDefaultLocationCommand()
                    Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$CommandName] $($this.RowName()): Uses default location, must get from Civic Address!"
                    $l.Add([ChangeObject]@{
                            UpdateType    = [UpdateType]::Online
                            ProcessInfo   = $gac
                            DependsOn     = $d
                            CommandType   = [CommandType]::GetAddress
                            CommandObject = $this._networkObject._location._address
                        })
                    $d.Add($this._networkObject._location._address.Id)
                }
                $l.Add([ChangeObject]@{
                        UpdateType    = [UpdateType]::Online
                        ProcessInfo   = $nc
                        DependsOn     = $d
                        CommandType   = [CommandType]::NetworkObject
                        CommandObject = $this._networkObject
                    })
                $d.Add($this._networkObject.Id)
            }
        }
        $l.Add([ChangeObject]::new($this, $d))
        return $l
    }

    [string] ToHashString() {
        if ([string]::IsNullOrEmpty($this._hashString)) {
            $SelectParams = @{
                Property        = [E911DataRow]::Properties
            }
            $this._hashString = $this._originalRow | Select-Object @SelectParams | ConvertTo-Json -Compress
        }
        return $this._hashString
    }
    [string] ToString() {
        $SelectParams = @{
            Property        = [E911DataRow]::Properties + @(@{ Name = 'EntryHash'; Expression = { $this.EntryHash } })
        }
        if ($this.HasWarnings()) {
            $SelectParams['Property'] += @(@{ Name = 'Warning'; Expression = { $this.Warning.ToString() } })
        }
        $this._string = $this._originalRow | Select-Object @SelectParams | ConvertTo-Json -Compress
        $this._lastWarnCount = $this.Warning.Count()
        return $this._string
    }

    [string] GetHash() {
        if ([string]::IsNullOrEmpty($this._hash)) {
            $this._hash = [Hasher]::GetHash($this.ToHashString())
        }
        return $this._hash
    }

    hidden [void] _AddCompanyName() {
        $this | Add-Member -Name CompanyName -MemberType ScriptProperty -Value {
            return $this._networkObject._location.CompanyName
        }
    }
    hidden [void] _AddCompanyTaxId() {
        $this | Add-Member -Name CompanyTaxId -MemberType ScriptProperty -Value {
            return $this._networkObject._location.CompanyTaxId
        }
    }
    hidden [void] _AddDescription() {
        $this | Add-Member -Name Description -MemberType ScriptProperty -Value {
            return $this._networkObject._location.Description
        }
    }
    hidden [void] _AddAddress() {
        $this | Add-Member -Name Address -MemberType ScriptProperty -Value {
            return $this._networkObject._location.Address
        }
    }
    hidden [void] _AddLocation() {
        $this | Add-Member -Name Location -MemberType ScriptProperty -Value {
            return $this._networkObject._location.Location
        }
    }
    hidden [void] _AddCity() {
        $this | Add-Member -Name City -MemberType ScriptProperty -Value {
            return $this._networkObject._location.City
        }
    }
    hidden [void] _AddStateOrProvince() {
        $this | Add-Member -Name StateOrProvince -MemberType ScriptProperty -Value {
            return $this._networkObject._location.StateOrProvince
        }
    }
    hidden [void] _AddPostalCode() {
        $this | Add-Member -Name PostalCode -MemberType ScriptProperty -Value {
            return $this._networkObject._location.PostalCode
        }
    }
    hidden [void] _AddCountryOrRegion() {
        $this | Add-Member -Name CountryOrRegion -MemberType ScriptProperty -Value {
            return $this._networkObject._location.CountryOrRegion
        }
    }
    hidden [void] _AddLatitude() {
        $this | Add-Member -Name Latitude -MemberType ScriptProperty -Value {
            return $this._networkObject._location.Latitude
        }
    }
    hidden [void] _AddLongitude() {
        $this | Add-Member -Name Longitude -MemberType ScriptProperty -Value {
            return $this._networkObject._location.Longitude
        }
    }
    hidden [void] _AddELIN() {
        $this | Add-Member -Name Elin -MemberType ScriptProperty -Value {
            return $this._networkObject._location.Elin
        }
    }
    hidden [void] _AddNetworkDescription() {
        $this | Add-Member -Name NetworkDescription -MemberType ScriptProperty -Value {
            return $this._networkObject.Description
        }
    }
    hidden [void] _AddNetworkObjectType() {
        $this | Add-Member -Name NetworkObjectType -MemberType ScriptProperty -Value {
            return $this._networkObject.Type
        }
    }
    hidden [void] _AddNetworkObjectIdentifier() {
        $this | Add-Member -Name NetworkObjectIdentifier -MemberType ScriptProperty -Value {
            return $this._networkObject.Identifier
        }
    }
    hidden [void] _AddEntryHash() {
        $this | Add-Member -Name EntryHash -MemberType ScriptProperty -Value {
            return $this.GetHash()
        }
    }
}

# (imported from .\classes\E911Location.ps1)
class E911Location {
    hidden [ItemId] $Id
    hidden [bool] $_isOnline
    hidden [bool] $_hasChanged
    hidden [bool] $_isDefault
    hidden [string] $_hash
    hidden [string] $_command
    hidden [E911Address] $_address

    E911Location ([PSCustomObject] $obj, [bool] $ShouldValidate) {
        if (![string]::IsNullOrEmpty($obj.LocationId)) {
            $this._isOnline = $true
            $this.Id = [ItemId]::new($obj.LocationId)
        }
        else {
            $this.Id = [ItemId]::new()
            $this._isOnline = $false
        }
        $this._hasChanged = $false
        $this.Warning = [WarningList]::new()
        try {
            $this._address = [E911ModuleState]::GetOrCreateAddress($obj, $ShouldValidate)
        }
        catch {
            $this.Warning.Add([WarningType]::InvalidInput, "Address Creation Failed: $($_.Exception.Message)")
        }
        if ($null -ne $this._address.Warning -and $this._address.Warning.HasWarnings()) {
            $this.Warning.AddRange($this._address.Warning)
        }
        if ($ShouldValidate -and [string]::IsNullOrEmpty($obj.Location)) {
            $this.Warning.Add([WarningType]::InvalidInput, 'Location missing')
        }
        $this.Location = $obj.Location
        $this.Elin = $obj.Elin

        $this._AddCompanyName()
        $this._AddCompanyTaxId()
        $this._AddDescription()
        $this._AddAddress()
        $this._AddCity()
        $this._AddStateOrProvince()
        $this._AddPostalCode()
        $this._AddCountryOrRegion()
        $this._AddLatitude()
        $this._AddLongitude()
    }

    E911Location ([PSCustomObject] $obj, [bool] $ShouldValidate, [bool] $Default) {
        if (![string]::IsNullOrEmpty($obj.LocationId)) {
            # made via online location w/ no location field (default)
            $this._isOnline = $true
            $this.Id = [ItemId]::new($obj.LocationId)
            # $ raw location id for variable here
            
        }
        elseif (![string]::IsNullOrEmpty($obj.DefaultLocationId)) {
            # if location is made via civicaddress
            $this._isOnline = $true
            $this.Id = [ItemId]::new($obj.DefaultLocationId)
            # $CivicAddressIdVar + .DefaultLocationId
        }
        else {
            # new entry for default location
            $this._isOnline = $false
            $this.Id = [ItemId]::new()
        }
        $this._isDefault = $true
        $this._hasChanged = $false
        $this.Warning = [WarningList]::new()
        try {
            $this._address = [E911ModuleState]::GetOrCreateAddress($obj, $ShouldValidate)
        }
        catch {
            $this.Warning.Add([WarningType]::InvalidInput, "Address Creation Failed: $($_.Exception.Message)")
        }
        if ($null -ne $this._address.Warning -and $this._address.Warning.HasWarnings()) {
            $this.Warning.AddRange($this._address.Warning)
        }
        $this.Location = $obj.Location
        $this.Elin = $obj.Elin

        $this._AddCompanyName()
        $this._AddCompanyTaxId()
        $this._AddDescription()
        $this._AddAddress()
        $this._AddCity()
        $this._AddStateOrProvince()
        $this._AddPostalCode()
        $this._AddCountryOrRegion()
        $this._AddLatitude()
        $this._AddLongitude()
    }

    hidden E911Location() {}

    [string] $Location

    [AllowEmptyString()]
    [string] $Elin

    [WarningList] $Warning

    [bool] HasWarnings() {
        if ($null -ne $this._address -and $this._address.HasWarnings()) {
            $this.Warning.AddRange($this._address.Warning)
        }
        return $null -ne $this.Warning -and $this.Warning.HasWarnings()
    }

    [bool] ValidationFailed() {
        if ($this._address.ValidationFailed()) {
            $this.Warning.AddRange($this._address.Warning)
        }
        return $this.Warning.ValidationFailed()
    }

    [int] ValidationFailureCount() {
        if ($this._address.ValidationFailed()) {
            $this.Warning.AddRange($this._address.Warning)
        }
        return $this.Warning.ValidationFailureCount()
    }

    [string] HouseNumber() {
        return $this._address.HouseNumber()
    }

    [string] StreetName() {
        return $this._address.StreetName()
    }

    [string] GetCommand() {
        if ([string]::IsNullOrEmpty($this._command) -and $this._hasChanged -and !$this._isDefault) {
            $sb = [Text.StringBuilder]::new()
            $CivicAddressId = '{0}.CivicAddressId' -f $this._address.Id.VariableName()
            if ($this._address._isOnline) {
                $CivicAddressId = '"{0}"' -f $this._address.Id.ToString()
            }
            $LocationParams = @{
                CivicAddressId = $CivicAddressId
                Location       = '"{0}"' -f $this.Location
            }
            if (![string]::IsNullOrEmpty($this.Elin)) {
                $LocationParams['Elin'] = '"{0}"' -f $this.Elin
            }
            [void]$sb.AppendFormat('{0} = New-CsOnlineLisLocation -ErrorAction Stop', $this.Id.VariableName())
            foreach ($Parameter in $LocationParams.Keys) {
                [void]$sb.AppendFormat(' -{0} {1}', $Parameter, $LocationParams[$Parameter])
            }
            $this._command = $sb.ToString()
        }
        return $this._command
    }

    static [string] GetHash([PSCustomObject] $obj) {
        $addr = [E911Address]::_convertOnlineAddress($obj)
        if ([string]::IsNullOrEmpty($addr)) {
            $addr = $obj.Address
        }
        $test = [PSCustomObject]@{
            CompanyName     = $obj.CompanyName
            Address         = $addr -replace '\s+', ' '
            City            = $obj.City
            StateOrProvince = $obj.StateOrProvince
            PostalCode      = $obj.PostalCode
            CountryOrRegion = $obj.CountryOrRegion
        }
        $AString = ($test | Select-Object -Property ([E911Address]::_addressHashProps) | ConvertTo-Json -Compress).ToLower()
        $LString = "$($obj.Location)$($obj.Elin)".ToLower()
        $AHash = [Hasher]::GetHash($AString)
        return [Hasher]::GetHash("${AHash}${LString}")
    }

    [string] GetHash() {
        if ([string]::IsNullOrEmpty($this._hash)) {
            $this._hash = [Hasher]::GetHash("$($this._address.GetHash())$($this.Location.ToLower())$($this.Elin.ToLower())")
        }
        return $this._hash
    }

    static [bool] Equals($Value1, $Value2) {
        if ($null -eq $Value1 -and $null -eq $Value2) {
            return $true
        }
        if ($null -eq $Value1 -or $null -eq $Value2) {
            return $false
        }
        return [E911Location]::GetHash($Value1) -eq [E911Location]::GetHash($Value2)
    }

    [bool] Equals($Value) {
        if ($null -eq $Value) {
            return $false
        }
        return $this.GetHash() -eq $Value.GetHash()
    }

    hidden [void] _AddCompanyName() {
        $this | Add-Member -Name CompanyName -MemberType ScriptProperty -Value {
            return $this._address.CompanyName
        }
    }
    hidden [void] _AddCompanyTaxId() {
        $this | Add-Member -Name CompanyTaxId -MemberType ScriptProperty -Value {
            return $this._address.CompanyTaxId
        }
    }
    hidden [void] _AddDescription() {
        $this | Add-Member -Name Description -MemberType ScriptProperty -Value {
            return $this._address.Description
        }
    }
    hidden [void] _AddAddress() {
        $this | Add-Member -Name Address -MemberType ScriptProperty -Value {
            return $this._address.Address
        }
    }
    hidden [void] _AddCity() {
        $this | Add-Member -Name City -MemberType ScriptProperty -Value {
            return $this._address.City
        }
    }
    hidden [void] _AddStateOrProvince() {
        $this | Add-Member -Name StateOrProvince -MemberType ScriptProperty -Value {
            return $this._address.StateOrProvince
        }
    }
    hidden [void] _AddPostalCode() {
        $this | Add-Member -Name PostalCode -MemberType ScriptProperty -Value {
            return $this._address.PostalCode
        }
    }
    hidden [void] _AddCountryOrRegion() {
        $this | Add-Member -Name CountryOrRegion -MemberType ScriptProperty -Value {
            return $this._address.CountryOrRegion
        }
    }
    hidden [void] _AddLatitude() {
        $this | Add-Member -Name Latitude -MemberType ScriptProperty -Value {
            return $this._address.Latitude
        }
    }
    hidden [void] _AddLongitude() {
        $this | Add-Member -Name Longitude -MemberType ScriptProperty -Value {
            return $this._address.Longitude
        }
    }
}

# (imported from .\classes\E911ModuleState.ps1)
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
    hidden static [System.Collections.Generic.Dictionary[string, E911Location]] $OnlineDefaultLocations = [System.Collections.Generic.Dictionary[string, E911Location]]::new()
    hidden static [System.Collections.Generic.Dictionary[string, E911Location]] $DefaultLocations = [System.Collections.Generic.Dictionary[string, E911Location]]::new()
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
        if ((!$_.isOnline -and $ShouldValidate) -or $OnlineChanged) {
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
    static [E911Location] GetDefaultLocation([PSCustomObject] $obj, [bool]$ShouldValidate) {
        $OnlineChanged = $false
        $Online = $null
        if (![string]::IsNullOrEmpty($obj.LocationId) -and [E911ModuleState]::OnlineDefaultLocations.ContainsKey($obj.LocationId.ToLower())) {
            $Online = [E911ModuleState]::OnlineDefaultLocations[$obj.LocationId.ToLower()]
            if ([E911Address]::Equals($Online, $obj)) {
                return $Online
            }
            $OnlineChanged = $true
        }
        if (!$OnlineChanged -and ![string]::IsNullOrEmpty($obj.DefaultLocationId) -and [E911ModuleState]::OnlineDefaultLocations.ContainsKey($obj.DefaultLocationId.ToLower())) {
            $Online = [E911ModuleState]::OnlineDefaultLocations[$obj.DefaultLocationId.ToLower()]
            if ([E911Address]::Equals($Online, $obj)) {
                return $Online
            }
            $OnlineChanged = $true
        }
        $Hash = [E911Address]::GetHash($obj)
        if ([E911ModuleState]::DefaultLocations.ContainsKey($Hash)) {
            $Test = [E911ModuleState]::DefaultLocations[$Hash]
            if ([E911Address]::Equals($Test, $obj)) {
                return $Test
            }
        }
        if ($null -eq $Online -and [E911ModuleState]::OnlineDefaultLocations.ContainsKey($Hash)) {
            $Online = [E911ModuleState]::OnlineDefaultLocations[$Hash]
            if ([E911Address]::Equals($Online, $obj) -and $Online.Elin -eq $obj.Elin) {
                return $Online
            }
            $OnlineChanged = $true
        }
        $New = [E911Location]::new($obj, $ShouldValidate, $true)
        if ((!$_.isOnline -and $ShouldValidate)) {
            $New._hasChanged = $true
            [E911ModuleState]::DefaultLocations.Add($Hash, $New)
        }
        if ($OnlineChanged) {
            $New._hasChanged = $true
            [E911ModuleState]::OnlineDefaultLocations[$Hash] = $New
            [E911ModuleState]::OnlineDefaultLocations[$New.Id.ToString().ToLower()] = $New
        }
        if ($New._isOnline -and !$OnlineChanged) {  # initial adding of online default location
            [E911ModuleState]::OnlineDefaultLocations.Add($Hash, $New)
            [E911ModuleState]::OnlineDefaultLocations.Add($New.Id.ToString().ToLower(), $New)
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
            $OnlineChanged = $true
        }
        $Hash = [E911Location]::GetHash($obj)
        if ([E911ModuleState]::Locations.ContainsKey($Hash)) {
            return [E911ModuleState]::Locations[$Hash]
        }
        if ($null -eq $Online -and [E911ModuleState]::OnlineLocations.ContainsKey($Hash)) {
            $Online = [E911ModuleState]::OnlineLocations[$Hash]
            if ([E911Location]::Equals($Online, $obj)) {
                return $Online
            }
            $OnlineChanged = $true
        }
        $New = [E911Location]::new($obj, $ShouldValidate)
        if ((!$_.isOnline -and $ShouldValidate) -or $OnlineChanged) {
            $New._hasChanged = $true
            [E911ModuleState]::Locations.Add($New.GetHash(), $New)
        }
        if ($OnlineChanged) {
            $New._hasChanged = $true
            [E911ModuleState]::OnlineLocations[$New.GetHash()] = $New
            [E911ModuleState]::OnlineLocations[$New.Id.ToString().ToLower()] = $New
        }
        if ($New._isOnline -and !$OnlineChanged) {
            [E911ModuleState]::OnlineLocations.Add($New.GetHash(), $New)
            [E911ModuleState]::OnlineLocations.Add($New.Id.ToString().ToLower(), $New)
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
                return $Online
            }
            $OnlineChanged = $true
        }
        $New = [E911NetworkObject]::new($obj, $ShouldValidate)
        if ($dup) {
            $New.Warning.Add([WarningType]::DuplicateNetworkObject, "$($New.Type):$($New.Identifier) exists in other rows")
        }
        if (!$dup -and $New.Type -ne [NetworkObjectType]::Unknown -and ((!$_.isOnline -and $ShouldValidate) -or $OnlineChanged)) {
            $New._hasChanged = $true
            [E911ModuleState]::NetworkObjects.Add($New.GetHash(), $New)
        }
        if ($OnlineChanged) {
            $New._hasChanged = $true
            [E911ModuleState]::OnlineNetworkObjects[$New.GetHash()] = $New
        }
        if ($New._isOnline -and !$OnlineChanged) {
            [E911ModuleState]::OnlineNetworkObjects.Add($New.GetHash(), $New)
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
        $OnlineDefLocCount = [E911ModuleState]::OnlineDefaultLocations.Count
        $DefLocCount = [E911ModuleState]::DefaultLocations.Count
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
        [E911ModuleState]::OnlineDefaultLocations.Clear()
        Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$CommandName] $($OnlineDefLocCount - [E911ModuleState]::OnlineDefaultLocations.Count) Online Default Locations Removed"
        [E911ModuleState]::DefaultLocations.Clear()
        Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$CommandName] $($DefLocCount - [E911ModuleState]::DefaultLocations.Count) Default Locations Removed"
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

    static [void] InitializeCaches([Diagnostics.Stopwatch] $vsw) {
        $shouldstop = $false
        if ($null -eq $vsw) {
            $vsw = [Diagnostics.Stopwatch]::StartNew()
            $shouldstop = $true
        }
        $CommandName = [E911ModuleState]::GetCommandName()
        Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$CommandName] Populating Caches..."
        if ([E911ModuleState]::ShouldClear) {
            [E911ModuleState]::FlushCaches($vsw)
        }
        $oAddresses = Get-CsOnlineLisCivicAddress
        foreach ($oAddress in $oAddresses) {
            [void][E911ModuleState]::GetOrCreateAddress($oAddress, $false)
            [void][E911ModuleState]::GetDefaultLocation($oAddress, $false)
        }
        Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$CommandName] Cached $($oAddresses.Count) Civic Addresses"
        $oLocations = Get-CsOnlineLisLocation
        foreach ($oLocation in $oLocations) {
            [void][E911ModuleState]::GetOrCreateLocation($oLocation, $false)
        }
        Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$CommandName] Cached $($oLocations.Count) Locations"
        $nObjectCount = 0
        foreach ($n in [Enum]::GetNames([NetworkObjectType])) {
            if ($n -eq 'Unknown') { continue }
            $oObjects = Invoke-Command -NoNewScope ([ScriptBlock]::Create(('Get-CsOnlineLis{0}' -f $n)))
            $nObjectCount += $oObjects.Count
            foreach ($oObject in $oObjects) {
                [void][E911ModuleState]::GetOrCreateNetworkObject($oObject, $false)
            }
        }
        if ($shouldstop) {
            $vsw.Stop()
        }
        Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$CommandName] Cached $nObjectCount Network Objects"
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

# (imported from .\classes\E911NetworkObject.ps1)
class E911NetworkObject {
    hidden [ItemId] $Id
    hidden [bool] $_isOnline
    hidden [bool] $_hasChanged
    hidden [bool] $_isDuplicate
    hidden [string] $_hash
    hidden [string] $_command
    hidden [string] $_locationId
    hidden [E911Location] $_location

    # override init to allow for pseudo constructor chaining
    hidden Init([string]$newType, [string]$newIdentifier, [string] $Description) {
        if ([string]::IsNullOrEmpty($newType)) { $newType = 'Unknown' }
        $this.Init([NetworkObjectType]$newType, [NetworkObjectIdentifier]::new($newIdentifier), $Description)
    }
    hidden Init([NetworkObjectType]$type, [NetworkObjectIdentifier]$identifier, [string] $Description) {
        $this.Type = $type
        $this.Identifier = $identifier
        $this.Description = $Description
        # need to add some default description generation?
        if ($null -eq $this.Warning) {
            $this.Warning = [WarningList]::new()
        }
        if ($null -ne $this._location -and $null -ne $this._location.Warning -and $this._location.Warning.HasWarnings()) {
            $this.Warning.AddRange($this._location.Warning)
        }
        $this.Id = [ItemId]::new()
        $this._isDuplicate = $false
        $this._hasChanged = $false
    }
    hidden Init([PSCustomObject]$obj, [bool] $ShouldValidate) {
        $NetworkObjectType = $obj.NetworkObjectType
        $NetworkObjectIdentifier = $obj.NetworkObjectIdentifier
        if ($ShouldValidate) {
            $this.Warning = [WarningList]::new()
            try {
                $NetworkObjectType = if ([string]::IsNullOrEmpty($NetworkObjectType)) { [NetworkObjectType]::Unknown } else { [NetworkObjectType]$NetworkObjectType }
            }
            catch {
                [void]$this.Warning.Add([WarningType]::InvalidInput, "NetworkObjectType '$NetworkObjectType'")
            }
            if ($NetworkObjectType -eq [NetworkObjectType]::Unknown) {
                [void]$this.Warning.Add([WarningType]::InvalidInput, "NetworkObjectType 'Unknown'")
            }
            if ([string]::IsNullOrWhiteSpace($NetworkObjectIdentifier) -and $NetworkObjectType -ne [NetworkObjectType]::Unknown) {
                [void]$this.Warning.Add([WarningType]::InvalidInput, "NetworkObjectIdentifier missing")
            }
            else {
                try {
                    $NetworkObjectIdentifier = [NetworkObjectIdentifier]::new($NetworkObjectIdentifier)
                }
                catch {
                    [void]$this.Warning.Add([WarningType]::InvalidInput, "NetworkObjectIdentifier '$NetworkObjectIdentifier'")
                }
            }
        }
        if ([string]::IsNullOrEmpty($obj.Location)) {
            $this._location = [E911ModuleState]::GetDefaultLocation($obj, $ShouldValidate)
        }
        else {
            $this._location = [E911ModuleState]::GetOrCreateLocation($obj, $ShouldValidate)
        }
        $Desc = if ($null -eq $obj.LocationId) { $obj.NetworkDescription } else { $obj.Description }
        $this.Init($NetworkObjectType, $NetworkObjectIdentifier, $Desc)
    }
    hidden Init([PSCustomObject]$obj) {
        if (![string]::IsNullOrEmpty($obj.LocationId)) {
            $this._locationId = $obj.LocationId
            $this._isOnline = $true
        }
        $newType = 'Unknown'
        $newIdentifier = ''
        if ($null -ne $obj.ChassisId) {
            $newType = 'Switch'
            $newIdentifier = $obj.ChassisId
            if ($null -ne $obj.PortId) {
                $newType = 'Port'
                $newIdentifier += ";$($obj.PortId)"
            }
        }
        if ($null -ne $obj.Bssid) {
            $newType = 'WirelessAccessPoint'
            $newIdentifier = $obj.Bssid
        }
        if ($null -ne $obj.Subnet) {
            $newType = 'Subnet'
            $newIdentifier = $obj.Subnet
        }
        if ($newType -eq 'Unknown') {
            $this.Init($obj, $true)
            return
        }
        if ([string]::IsNullOrEmpty($obj.Location)) {
            $this._location = [E911ModuleState]::GetDefaultLocation($obj, $false)
        }
        else {
            $this._location = [E911ModuleState]::GetOrCreateLocation($obj, $false)
        }
        $this.Init($newType, $newIdentifier, $obj.Description)
    }

    E911NetworkObject([NetworkObjectType]$newType, [NetworkObjectIdentifier]$newIdentifier, [string] $Description) {
        $this.Init($newType, $newIdentifier, $Description)
    }

    E911NetworkObject([string]$newType, [string]$newIdentifier, [string] $Description) {
        $this.Init($newType, $newIdentifier, $Description)
    }

    E911NetworkObject() {
        $this.Init([NetworkObjectType]::Unknown, [NetworkObjectIdentifier]::new([string]::Empty), [string]::Empty)
    }

    E911NetworkObject([PSCustomObject]$obj, [bool] $ShouldValidate) {
        if (![string]::IsNullOrEmpty($obj.LocationId)) {
            $this.Init($obj)
            return
        }
        $this.Init($obj, $ShouldValidate)
    }

    E911NetworkObject([PSCustomObject]$obj) {
        if (![string]::IsNullOrEmpty($obj.LocationId)) {
            $this.Init($obj)
            return
        }
        $this.Init($obj, $true)
    }

    [NetworkObjectType] $Type
    [NetworkObjectIdentifier] $Identifier
    [string] $Description

    [WarningList] $Warning

    [string] GetCommand([bool] $UseVariable) {
        if ($this.Type -eq [NetworkObjectType]::Unknown -or $null -eq $this._location) {
            return ''
        }
        if ([string]::IsNullOrEmpty($this._command) -and $this._hasChanged) {
            $sb = [Text.StringBuilder]::new()
            if ($UseVariable) {
                if ($this._location._isDefault) {
                    $LocationId = '{0}.DefaultLocationId' -f $this._location._address.Id.VariableName()
                }
                else {
                    $LocationId = '{0}.LocationId' -f $this._location.Id.VariableName()
                } 
            }
            else <# ($this._location._isOnline) #> {
                $LocationId = '"{0}"' -f $this._location.Id.ToString()
            }
            [void]$sb.AppendFormat('Set-CsOnlineLis{0} -LocationId {1}', $this.Type, $LocationId)
            if (![string]::IsNullOrEmpty($this.Description)) {
                [void]$sb.AppendFormat(' -Description "{0}"', $this.Description)
            }
            if ($this.Type -eq [NetworkObjectType]::Switch -or $this.Type -eq [NetworkObjectType]::Port) {
                [void]$sb.AppendFormat(' -ChassisID "{0}"', $this.Identifier.PhysicalAddress)
            }
            if ($this.Type -eq [NetworkObjectType]::Port) {
                [void]$sb.AppendFormat(' -PortId "{0}"', $this.Identifier.PortId)
            }
            if ($this.Type -eq [NetworkObjectType]::Subnet) {
                [void]$sb.AppendFormat(' -Subnet "{0}"', $this.Identifier.SubnetId.ToString())
            }
            if ($this.Type -eq [NetworkObjectType]::WirelessAccessPoint) {
                [void]$sb.AppendFormat(' -BSSID "{0}"', $this.Identifier.PhysicalAddress)
            }
            [void]$sb.Append(' -ErrorAction Stop | Out-Null')
            $this._command = $sb.ToString()
        }
        return $this._command
    }

    [bool] HasWarnings() {
        if ($null -ne $this._location -and $this._location.HasWarnings()) {
            $this.Warning.AddRange($this._location.Warning)
        }
        return $null -ne $this.Warning -and $this.Warning.HasWarnings()
    }

    [bool] ValidationFailed() {
        if ($null -ne $this._location -and $this._location.ValidationFailed()) {
            $this.Warning.AddRange($this._location.Warning)
        }
        return $this.Warning.ValidationFailed()
    }
    [int] ValidationFailureCount() {
        if ($null -ne $this._location -and $this._location.ValidationFailed()) {
            $this.Warning.AddRange($this._location.Warning)
        }
        return $this.Warning.ValidationFailureCount()
    }

    static [string] GetHash([PSCustomObject] $obj) {
        $newType = 'Unknown'
        $newIdentifier = ''
        if ($null -ne $obj.ChassisId) {
            $newType = 'Switch'
            $newIdentifier = $obj.ChassisId
            if ($null -ne $obj.PortId) {
                $newType = 'Port'
                $newIdentifier += ";$($obj.PortID)"
            }
        }
        if ($null -ne $obj.Bssid) {
            $newType = 'WirelessAccessPoint'
            $newIdentifier = $obj.Bssid
        }
        if ($null -ne $obj.Subnet) {
            $newType = 'Subnet'
            $newIdentifier = $obj.Subnet
        }
        if ($newType -eq 'Unknown' -and [string]::IsNullOrEmpty($newIdentifier)) {
            $newType = if ([string]::IsNullOrEmpty($obj.NetworkObjectType)) { $newType } else { $obj.NetworkObjectType }
            $newIdentifier = if ([string]::IsNullOrEmpty($obj.NetworkObjectIdentifier)) { $newIdentifier } else { $obj.NetworkObjectIdentifier }
        }
        if ($newType -eq 'Unknown' -and [string]::IsNullOrEmpty($newIdentifier)) {
            $newType = if ([string]::IsNullOrEmpty($obj.Type)) { $newType } else { $obj.Type }
            $newIdentifier = if ([string]::IsNullOrEmpty($obj.Identifier)) { $newIdentifier } else { $obj.Identifier }
        }
        $newType = [NetworkObjectType]$newType
        $newIdentifier = [NetworkObjectIdentifier]::new($newIdentifier)
        $hash = [Hasher]::GetHash(("${newType}${newIdentifier}").ToLower())
        return $hash
    }

    [string] GetHash() {
        if ([string]::IsNullOrEmpty($this._hash)) {
            $this._hash = [Hasher]::GetHash(("$($this.Type)$($this.Identifier)").ToLower())
        }
        return $this._hash
    }

    static [bool] Equals($Value1, $Value2) {
        if ($null -eq $Value1 -and $null -eq $Value2) {
            return $true
        }
        if ($null -eq $Value1 -or $null -eq $Value2) {
            return $false
        }
        if ([E911NetworkObject]::GetHash($Value1) -ne [E911NetworkObject]::GetHash($Value2)) {
            return $false
        }
        $Desc1 = if ($null -eq $Value1.LocationId -and $Value1 -isnot [E911NetworkObject]) { $Value1.NetworkDescription } else { $Value1.Description }
        $Desc2 = if ($null -eq $Value2.LocationId -and $Value2 -isnot [E911NetworkObject]) { $Value2.NetworkDescription } else { $Value2.Description }
        $D1 = if ([string]::IsNullOrEmpty($Desc1)) { '' } else { $Desc1 }
        $D2 = if ([string]::IsNullOrEmpty($Desc2)) { '' } else { $Desc2 }

        return $D1 -eq $D2
    }

    [bool] Equals($Value) {
        if ($null -eq $Value) {
            return $false
        }
        if ($this.GetHash() -ne $Value.GetHash()) {
            return $false
        }
        return $this.Description -eq $Value.Description
    }
}

# (imported from .\classes\Hasher.ps1)
class Hasher {
    hidden static $_hashAlgorithm = [System.Security.Cryptography.HashAlgorithm]::Create('sha256')

    static [string] GetHash([string] $string) {
        return [Convert]::ToBase64String([Hasher]::_hashAlgorithm.ComputeHash([Text.Encoding]::UTF8.GetBytes($string)))
    }
}

# (imported from .\classes\ItemId.ps1)
class ItemId {
    hidden [string] $_variableName

    # override init to allow for pseudo constructor chaining
    hidden Init([Object]$inputId = $null) {
        if ($inputId -is [ItemId]) {
            $this.Id = $inputId.Id
            return
        }
        if ([string]::IsNullOrEmpty($inputId) -or !($inputId -is [string] -or $inputId -is [Guid])) {
            $inputId = [Guid]::NewGuid()
        }
        $this.Id = [Guid]$inputId
    }
    ItemId() {
        $this.Init($null)
    }
    ItemId([Object]$inputId = $null) {
        $this.Init($inputId)
    }

    [Guid] $Id

    [string] VariableName() {
        if ([string]::IsNullOrEmpty($this._variableName)) { $this._variableName = '${0}' -f $this.ToString().Replace('-', '') }
        return $this._variableName
    }
    [string] Trim() {
        return $this.ToString().Trim()
    }
    [string] ToString() {
        if ($null -eq $this.Id) { $this.Id = [Guid]::NewGuid() }
        return $this.Id.Guid
    }
    [bool] Equals($Other) {
        if ($null -eq $Other) {
            return $false
        }
        return $this.Id -eq $Other.Id
    }
}

# (imported from .\classes\NetworkObjectIdentifier.ps1)
class NetworkObjectIdentifier {
    [string] $PhysicalAddress
    [string] $PortId
    [System.Net.IPAddress] $SubnetId

    NetworkObjectIdentifier ([string] $NetworkObjectString) {
        if ([string]::IsNullOrEmpty($NetworkObjectString)) {
            return
        }
        $tryParts = $NetworkObjectString.Split(';')
        if ($tryParts.Count -eq 2) {
            $this.PhysicalAddress = [NetworkObjectIdentifier]::TryConvertToPhysicalAddressString($tryParts[0].Trim())
            $this.PortId = $tryParts[1].Trim()
            return
        }
        $addr = [NetworkObjectIdentifier]::TryConvertToPhysicalAddressString($NetworkObjectString.Trim())
        if (![string]::IsNullOrEmpty($addr)) {
            $this.PhysicalAddress = $addr
            return
        }
        $addr = [System.Net.IPAddress]::Any
        if ([System.Net.IPAddress]::TryParse($NetworkObjectString.Trim(), [ref] $addr)) {
            $this.SubnetId = $addr
            return
        }
        throw
    }

    [string] ToString() {
        $sb = [System.Text.StringBuilder]::new()
        if (![string]::IsNullOrEmpty($this.PhysicalAddress)) {
            [void]$sb.Append($this.PhysicalAddress)
            if (![string]::IsNullOrEmpty($this.PortId)) {
                [void]$sb.Append(';')
                [void]$sb.Append($this.PortId)
            }
            return $sb.ToString()
        }
        if ($null -ne $this.SubnetId) {
            [void]$sb.Append($this.SubnetId.ToString())
        }
        return $sb.ToString()
    }

    hidden static [string] TryConvertToPhysicalAddressString([string]$addressString) {
        try {
            $address = $addressString.ToUpper() -replace '[^A-F0-9\*]', ''
            $addressParts = $address -split '(\w{2})' | Where-Object { ![string]::IsNullOrEmpty($_) }
            if ($addressParts.Count -ne 6) { return '' }
            $address = $addressParts -join '-'
            if ($addressParts[-1].EndsWith('*') -and $addressParts[-1].Length -in @(1, 2)) {
                for ($i = 0; $i -lt ($addressParts.Count - 1); $i++) {
                    if ($addressParts[$i] -notmatch '^[A-F0-9]{2}$') { return '' }
                }
                return $address
            }
            $pa = [Net.NetworkInformation.PhysicalAddress]::Parse($address)
            if ($pa) {
                return [BitConverter]::ToString($pa.GetAddressBytes())
            }
            return ''
        }
        catch {
            return [string]::Empty
        }
    }
}

# (imported from .\classes\NetworkObjectType.ps1)
enum NetworkObjectType {
    Unknown
    Subnet
    Switch
    Port
    WirelessAccessPoint
}

# (imported from .\classes\UpdateType.ps1)
enum UpdateType {
    Source
    Online
}

# (imported from .\classes\Warning.ps1)
class Warning {
    [WarningType] $Type
    [string] $Message
    Warning([string] $WarningString) {
        $Parts = $WarningString.Split(':', 2)
        $this.Type = [WarningType]$Parts[0]
        $this.Message = $Parts[1].Trim()
    }
    Warning([WarningType] $Type, [string] $Message) {
        $this.Type = $Type
        $this.Message = $Message.Trim()
    }
    [string] ToString() {
        return ('{0}:{1}' -f $this.Type, $this.Message)
    }
    [bool] Equals($Other) {
        if ($null -eq $Other) {
            return $false
        }
        return $this.Type -eq $Other.Type -and $this.Message -eq $Other.Message
    }
}

# (imported from .\classes\WarningList.ps1)
class WarningList {
    hidden [System.Collections.Generic.List[Warning]] $_items
    hidden [bool] $_mapsValidationFailed
    hidden [int] $_validationFailureCount
    hidden [int] $_itemCountWhenLastUpdatedValidationFailureCount

    WarningList() {
        $this._items = [System.Collections.Generic.List[Warning]]::new()
        $this._mapsValidationFailed = $false
    }
    WarningList([string] $WarningListString) {
        $this._items = [System.Collections.Generic.List[Warning]]::new()
        $this._mapsValidationFailed = $false
        if ([string]::IsNullOrEmpty($WarningListString)) {
            return
        }
        $Parts = $WarningListString.Split(';')
        foreach ($Part in $Parts) {
            $this.Add([Warning]::new($Part.Trim()))
        }
    }
    [void] Clear() {
        $this._items.Clear()
    }
    [int] Count() {
        return $this._items.Count
    }
    [bool] Contains([Warning] $Warning) {
        return $this._items.Contains($Warning)
    }
    [bool] HasWarnings() {
        return $this.Count() -gt 0
    }
    [bool] ValidationFailed() {
        return $this.ValidationFailureCount() -gt 0
    }
    [int] MapsValidationFailed() {
        return $this._mapsValidationFailed
    }
    [int] ValidationFailureCount() {
        if ($null -eq $this._validationFailureCount -or $this._itemCountWhenLastUpdatedValidationFailureCount -eq $this.Count()) {
            $this._validationFailureCount = $this._items.Where({ ($_.Type -band [WarningType]::ValidationErrors) -eq $_.Type }).Count
        }
        return $this._validationFailureCount
    }
    [void] Add([Warning] $Warning) {
        if ($this.Contains($Warning)) { return }
        if ([E911ModuleState]::WriteWarnings) {
            $CallStack = Get-PSCallStack
            if (($CallStack | Where-Object { $_.FunctionName.StartsWith('AddRange') }).Count -eq 0) {
                $CommandName = [E911ModuleState]::GetCommandName()
                Write-Warning ('[{0}] {1}' -f $CommandName, $Warning.ToString())
            }
        }
        if (!$this._mapsValidationFailed -and $Warning.Type -eq [WarningType]::MapsValidation) {
            $this._mapsValidationFailed = $true
        }
        $this._items.Add($Warning)
    }
    [void] AddAsString([string]$Warning) {
        $this.Add([Warning]::new($Warning))
    }
    [void] Add([WarningType] $Type, [string] $Message) {
        $this.Add([Warning]::new($Type, $Message))
    }
    [void] AddRange([System.Collections.Generic.IEnumerable[Warning]] $Ids) {
        foreach ($Id in $Ids) {
            $this.Add($Id)
        }
    }
    [void] AddRangeAsString([System.Collections.Generic.IEnumerable[string]] $Ids) {
        foreach ($Id in $Ids) {
            $this.AddAsString($Id)
        }
    }
    [void] AddRange([WarningList] $WarningList) {
        foreach ($Id in $WarningList.GetEnumerator()) {
            $this.Add($Id)
        }
    }
    [void] Insert([int]$Position, [Warning] $Warning) {
        $this._items.Insert($Position, $Warning)
    }
    [System.Collections.IEnumerator] GetEnumerator() {
        return $this._items.GetEnumerator()
    }
    [System.Collections.IEnumerator] GetEnumerator([int] $Index, [int] $Count) {
        return $this._items.GetEnumerator($Index, $Count)
    }
    [void] Remove([Warning] $Warning) {
        $this._items.Remove($Warning)
    }
    [string] ToString() {
        return ($this._items -join ';')
    }
}

# (imported from .\classes\WarningType.ps1)
[Flags()] enum WarningType {
    InvalidInput = 1
    MapsValidation = 2
    MapsValidationDetail = 4
    OnlineChangeError = 8
    DuplicateNetworkObject = 16
    GeneralFailure = 32
    ValidationErrors = 19 # [WarningType]::InvalidInput -bor [WarningType]::MapsValidation -bor [WarningType]::DuplicateNetworkObject
}

# (imported from .\public\Get-CsE911NeededChange.ps1)
function Get-CsE911NeededChange {
    [CmdletBinding()]
    [OutputType([ChangeObject])]
    param (
        # Parameter help description
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [E911DataRow[]]
        $LocationConfiguration,

        [switch]
        $ForceOnlineCheck
    )

    begin {
        $vsw = [Diagnostics.Stopwatch]::StartNew()
        $StartingCount = [E911ModuleState]::MapsQueryCount
        Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] Beginning..."
        try {
            [Microsoft.TeamsCmdlets.Powershell.Connect.TeamsPowerShellSession]::ClientAuthenticated()
            # maybe check for token expiration here?
        }
        catch {
            throw "Run Connect-MicrosoftTeams prior to executing this script!"
        }
        [E911ModuleState]::ForceOnlineCheck = $ForceOnlineCheck
        # initialize caches
        [E911ModuleState]::InitializeCaches($vsw)
        $Rows = [Collections.Generic.List[E911DataRow]]::new()
        Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] Validating Rows..."
        $i = 0
        $prevI = $i
        $shouldp = $true
        $interval = 2
        $LastSeconds = $vsw.Elapsed.TotalSeconds
    }
    process {
        foreach ($lc in $LocationConfiguration) {
            if ($MyInvocation.PipelinePosition -gt 1) {
                $Total = $Input.Count
            }
            else  {
                $Total = $LocationConfiguration.Count
            }
            if (($vsw.Elapsed.TotalSeconds - $LastSeconds) -gt ($interval + 1)) { $shouldp = $true }
            if ($i -eq 0 -or ($shouldp -and ($vsw.Elapsed.TotalSeconds - $LastSeconds) -gt $interval)) {
                if ($i -gt 0) { $shouldp = $false }
                $ProgressParams = @{
                    Activity = 'Validating Rows'
                    CurrentOperation = '[{0:F3}s] ({1}{2}) {3}' -f $vsw.Elapsed.TotalSeconds, $i, $(if($Total -gt 1) {"/$Total"}), $lc.RowName()
                    Id = $MyInvocation.PipelinePosition
                }
                if ($i -gt 0 -and $Total -gt 1) {
                    $LastSegment = $vsw.Elapsed.TotalSeconds - $LastSeconds
                    $Remaining = [int]((($Total - $i) / ($i - $prevI)) * $LastSegment)
                    $ProgressParams['PercentComplete'] = ($i / $Total * 100) 
                    $ProgressParams['SecondsRemaining'] = $Remaining
                }
                $LastSeconds = $vsw.Elapsed.TotalSeconds
                $prevI = $i
                Write-Progress @ProgressParams
            }
            $i++
            Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] [Row $i] $($lc.RowName()) Validating object..."
            if (!$lc.HasChanged()) {
                # no changes to this row since last processing, skip
                if (!$ForceOnlineCheck) {
                    Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] [Row $i] $($lc.RowName()) has not changed - skipping..."
                    [ChangeObject]::new($lc) | Write-Output
                    continue
                }
                Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] [Row $i] $($lc.RowName()) has not changed but ForceOnlineCheck is set..."
            }
            if ($lc.HasWarnings()) {
                Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] [Row $i] $($lc.RowName()): validation failed with $($lc.Warning.Count()) issue$(if($lc.Warning.Count() -gt 1) {'s'})!"
                [ChangeObject]::new($lc) | Write-Output
                continue
            }
            [void]$Rows.Add($lc)
        }
    }

    end {
        Write-Progress -Activity 'Validating Rows' -Completed -Id $MyInvocation.PipelinePosition
        Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] Processing Rows..."
        $i = 0
        $prevI = $i
        $shouldp = $true
        $interval = 15
        $LastSeconds = $vsw.Elapsed.TotalSeconds
        $Total = $Rows.Count
        $AddressChanges = [Collections.Generic.List[ItemId]]::new()
        $GetAddressChanges = [Collections.Generic.List[ItemId]]::new()
        $LocationChanges = [Collections.Generic.List[ItemId]]::new()
        foreach ($Row in $Rows) {
            if (($vsw.Elapsed.TotalSeconds - $LastSeconds) -gt ($interval + 1)) { $shouldp = $true }
            if ($i -eq 0 -or ($shouldp -and ($vsw.Elapsed.TotalSeconds - $LastSeconds) -gt $interval)) {
                if ($i -gt 0) { $shouldp = $false }
                $ProgressParams = @{
                    Activity = 'Generating Change Commands'
                    CurrentOperation = '[{0:F3}s] ({1}{2}) {3}' -f $vsw.Elapsed.TotalSeconds, $i, $(if($Total -gt 1) {"/$Total"}), $lc.RowName()
                    Id = $MyInvocation.PipelinePosition
                }
                if ($i -gt 0 -and $Total -gt 1) {
                    $LastSegment = $vsw.Elapsed.TotalSeconds - $LastSeconds
                    $Remaining = [int]((($Total - $i) / ($i - $prevI)) * $LastSegment)
                    $ProgressParams['PercentComplete'] = ($i / $Total * 100) 
                    $ProgressParams['SecondsRemaining'] = $Remaining
                }
                $LastSeconds = $vsw.Elapsed.TotalSeconds
                $prevI = $i
                Write-Progress @ProgressParams
            }
            $i++
            if ($Row.HasWarnings()) {
                Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] [Row $i] $($Row.RowName()): validation failed with $($Row.Warning.Count()) issue$(if($Row.Warning.Count() -gt 1) {'s'})!"
                [ChangeObject]::new($Row) | Write-Output
                continue
            }
            $Commands = $Row.GetChangeCommands($vsw)
            foreach ($Command in $Commands) {
                if ($Command.CommandType -eq [CommandType]::Address) {
                    if ($GetAddressChanges.Contains($Command.Id)) {
                        throw # this should not be possible
                    }
                    if ($AddressChanges.Contains($Command.Id) ) {
                        Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] $($Row.RowName()): Address change command already exists, skipping..."
                        continue
                    }
                    [void]$AddressChanges.Add($Command.Id)
                }
                if ($Command.CommandType -eq [CommandType]::GetAddress) {
                    if ($AddressChanges.Contains($Command.Id)) {
                        throw # this should not be possible
                    }
                    if ($GetAddressChanges.Contains($Command.Id) ) {
                        Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] $($Row.RowName()): Get address command already exists, skipping..."
                        continue
                    }
                    [void]$GetAddressChanges.Add($Command.Id)
                }
                if ($Command.CommandType -eq [CommandType]::Location) {
                    if ($LocationChanges.Contains($Command.Id)) {
                        Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] $($Row.RowName()): Location change command already exists, skipping..."
                        continue
                    }
                    [void]$LocationChanges.Add($Command.Id)
                }
                $Command | Write-Output
            }
        }
        $vsw.Stop()
        Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] Performed $([E911ModuleState]::MapsQueryCount - $StartingCount) Maps Queries"
        Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] Finished"
        Write-Progress -Activity 'Generating Change Commands' -Completed -Id $MyInvocation.PipelinePosition
    }
}

# (imported from .\public\Get-CsE911OnlineConfiguration.ps1)
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
            # maybe check for token expiration here?
        }
        catch {
            throw "Run Connect-MicrosoftTeams prior to executing this script!"
        }
        [E911ModuleState]::ForceOnlineCheck = $ForceOnlineCheck
        # initialize caches
        [E911ModuleState]::InitializeCaches($vsw)

        $FoundLocationHashes = [Collections.Generic.List[string]]::new()
        $FoundAddressHashes = [Collections.Generic.List[string]]::new()
    }

    process {
        foreach ($nObj in [E911ModuleState]::OnlineNetworkObjects.Values) {
            Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] Processing $($nObj.Type):$($nObj.Identifier)"
            if ($null -eq $nObj._location -or $null -eq $nObj._location._address) {
                Write-Warning "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] $($nObj.Type):$($nObj.Identifier) is orphaned!"
                # how should I write this out?
                continue
            }
            if ($null -ne $nObj._location -and !$FoundLocationHashes.Contains($nObj._location.GetHash())) {
                [void]$FoundLocationHashes.Add($nObj._location.GetHash())
            }
            if ($null -ne $nObj._location -and $null -ne $nObj._location._location -and !$FoundAddressHashes.Contains($nObj._location._address.GetHash())) {
                [void]$FoundAddressHashes.Add($nObj._location._address.GetHash())
            }
            $Row = [E911DataRow]::new($nObj)
            $Row.ToString() | ConvertFrom-Json | Write-Output
        }
        if ($IncludeOrphanedConfiguration) {
            foreach ($location in [E911ModuleState]::OnlineLocations.Values) {
                if ($location.GetHash() -in $FoundLocationHashes) {
                    continue
                }
                if ($null -eq $location._address -and !$IncludeOrphanedConfiguration) {
                    Write-Warning "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] $($location.Location) is orphaned!"
                    continue
                }
                # how should I handle these locations?
            }
            foreach ($address in [E911ModuleState]::OnlineAddresses.Values) {
                if ($address.GetHash() -in $FoundAddressHashes) {
                    continue
                }
                # how should I handle these addresses?
            }
        }

    }

    end {
        $vsw.Stop()
        Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] Finished"
    }
}

# (imported from .\public\Set-CsE911OnlineChange.ps1)
function Set-CsE911OnlineChange {
    [CmdletBinding(DefaultParameterSetName = 'Execute')]
    param (
        # Parameter help description
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'Execute')]
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'Validate')]
        [ChangeObject[]]
        $PendingChange,

        [Parameter(Mandatory = $true, ParameterSetName = 'Validate')]
        [switch]
        $ValidateOnly,

        [Parameter(Mandatory = $false, ParameterSetName = 'Validate')]
        [string]
        $ExecutionPlanPath
    )
    begin {
        $vsw = [Diagnostics.Stopwatch]::StartNew()
        Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] Beginning..."
        try {
            [Microsoft.TeamsCmdlets.Powershell.Connect.TeamsPowerShellSession]::ClientAuthenticated()
            # maybe check for token expiration here?
        }
        catch {
            throw "Run Connect-MicrosoftTeams prior to executing this script!"
        }
        if (![string]::IsNullOrEmpty($ExecutionPlanPath)) {
            # validate path is valid here, add header to file
            if (!(Test-Path -Path $ExecutionPlanPath -IsValid)) {
                $ExecutionPlanPath = ''
            }
            if ((Test-Path -Path $ExecutionPlanPath -PathType Container -ErrorAction SilentlyContinue)) {
                # get new file name:
                $FileName = 'E911ExecutionPlan_{0:yyyyMMdd_HHmmss}.txt' -f [DateTime]::Now
                $ExecutionPlanPath = Join-Path -Path $ExecutionPlanPath -ChildPath $FileName
            }
            try {
               Set-Content -Path $ExecutionPlanPath -ErrorAction Stop -Value '# *******************************************************************************'
               Add-Content -Path $ExecutionPlanPath -ErrorAction Stop -Value '# Teams E911 Automation generated execution plan'
               Add-Content -Path $ExecutionPlanPath -ErrorAction Stop -Value '# The following commands are what the workflow would execute in a live scenario'
               Add-Content -Path $ExecutionPlanPath -ErrorAction Stop -Value '# These must be executed from a valid MicrosoftTeams PowerShell session'
               Add-Content -Path $ExecutionPlanPath -ErrorAction Stop -Value '# These commands must be executed in-order in the same PowerShell session'
               Add-Content -Path $ExecutionPlanPath -ErrorAction Stop -Value '# *******************************************************************************'
               Add-Content -Path $ExecutionPlanPath -ErrorAction Stop -Value ''
            }
            catch {
                $ExecutionPlanPath = ''
            }
            if ([string]::IsNullOrEmpty($ExecutionPlanPath)) {
                Write-Warning "$($ExecutionPlanPath) is not a writeable path, execution plan will not be saved!"
            }
        }
        $PendingChanges = [Collections.Generic.Dictionary[int,Collections.Generic.List[ChangeObject]]]::new()
        $i = 0
        $prevI = $i
        $shouldp = $true
        $changeCount = 0
        $LastSeconds = $vsw.Elapsed.TotalSeconds
        $interval = 5
    }
    process {
        foreach ($Change in $PendingChange) {
            if ($MyInvocation.PipelinePosition -gt 1) {
                $Total = $Input.Count
            }
            else  {
                $Total = $PendingChange.Count
            }
            if (($vsw.Elapsed.TotalSeconds - $LastSeconds) -gt ($interval + 1)) { $shouldp = $true }
            if ($i -eq 0 -or ($shouldp -and ($vsw.Elapsed.TotalSeconds - $LastSeconds) -gt $interval)) {
                if ($i -gt 0) { $shouldp = $false }
                $ProgressParams = @{
                    Activity = 'Processing changes'
                    CurrentOperation = '[{0:F3}s] ({1}{2}) {3} Change: {4}' -f $vsw.Elapsed.TotalSeconds, $i, $(if($Total -gt 1) {"/$Total"}), $Change.UpdateType, $Change.Id
                    Id = $MyInvocation.PipelinePosition
                }
                if ($i -gt 0 -and $Total -gt 1) {
                    $LastSegment = $vsw.Elapsed.TotalSeconds - $LastSeconds
                    $Remaining = [int]((($Total - $i) / ($i - $prevI)) * $LastSegment)
                    $ProgressParams['PercentComplete'] = ($i / $Total) * 100 
                    $ProgressParams['SecondsRemaining'] = $Remaining
                }
                $LastSeconds = $vsw.Elapsed.TotalSeconds
                $prevI = $i
                Write-Progress @ProgressParams
            }
            $i++
            if ($null -ne $Change.CommandObject -and $Change.CommandObject.HasWarnings()) {
                Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] $($Change.Id) has warnings, skipping further processing"
                if ($Change.UpdateType -eq [UpdateType]::Source) {
                    $Change.DependsOn.Clear()
                    $Change.CommandObject | ConvertFrom-Json | Write-Output
                }
                continue
            }
            if ($Change.DependsOn.Count() -eq 0) {
                if ($Change.UpdateType -eq [UpdateType]::Source) {
                    Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] $($Change.Id) is a source change with no needed changes"
                    $Change.CommandObject | ConvertFrom-Json | Write-Output
                    continue
                }
                $changeCount++
                try {
                    Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] $($Change.ProcessInfo)"
                    if (!$ValidateOnly) {
                        Invoke-Command -ScriptBlock $Change.ProcessInfo -NoNewScope -ErrorAction Stop | Out-Null
                    }
                    if ($ValidateOnly -and $null -ne $ExecutionPlanPath) {
                        $Change.ProcessInfo.ToString() | Add-Content -Path $ExecutionPlanPath
                    }
                    [E911ModuleState]::ShouldClear = $true
                }
                catch {
                    $Change.CommandObject.Warning.Add([WarningType]::OnlineChangeError, "Command: { $($Change.ProcessInfo) } ErrorMessage: $($_.Exception.Message)")
                    Write-Warning "Command: { $($Change.ProcessInfo) } ErrorMessage: $($_.Exception.Message)"
                }
                continue
            }
            if (!$PendingChanges.ContainsKey($Change.DependsOn.Count())) {
                $PendingChanges[$Change.DependsOn.Count()] = [Collections.Generic.List[ChangeObject]]::new()
            }
            [void]$PendingChanges[$Change.DependsOn.Count()].Add($Change)
        }
    }
    end {
        if ($PendingChanges.Keys.Count -eq 0) {
            $vsw.Stop()
            Write-Progress -Activity 'Processing changes' -Completed -Id $MyInvocation.PipelinePosition
            Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] Finished"
            return
        }
        $shouldp = $true
        $LastSeconds = $vsw.Elapsed.TotalSeconds
        $prevI = $i
        $Total = $PendingChange.Count # $i + $PendingChanges.Values.ForEach({$_.Where({$_.UpdateType -eq [UpdateType]::Online})}).Count
        foreach ($DependencyCount in $PendingChanges.Keys) {
            foreach ($Change in $PendingChanges[$DependencyCount]) {
                if (($vsw.Elapsed.TotalSeconds - $LastSeconds) -gt ($interval + 1)) { $shouldp = $true }
                if ($shouldp -and ($vsw.Elapsed.TotalSeconds - $LastSeconds) -gt $interval) {
                    $shouldp = $false
                    $ProgressParams = @{
                        Activity = "Processing changes"
                        CurrentOperation = '[{0:F3}s] ({1}{2}) {3} Change: {4}' -f $vsw.Elapsed.TotalSeconds, $i, $(if($Total -gt 1) {"/$Total"}), $Change.UpdateType, $Change.Id
                        Id = $MyInvocation.PipelinePosition
                    }
                    if ($i -gt 0 -and $Total -gt 1) {
                        $SecondsPer = $i / $LastSeconds
                        # $LastSegment = $vsw.Elapsed.TotalSeconds - $LastSeconds
                        $Remaining = ($Total - $i) * $SecondsPer
                        $ProgressParams['PercentComplete'] = ($i / $Total) * 100 
                        $ProgressParams['SecondsRemaining'] = $Remaining
                    }
                    $LastSeconds = $vsw.Elapsed.TotalSeconds
                    $prevI = $i
                    Write-Progress @ProgressParams
                }
                $i++
                if ($null -ne $Change.CommandObject -and $Change.CommandObject.HasWarnings()) {
                    Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] $($Change.Id) has warnings, skipping further processing"
                    if ($Change.UpdateType -eq [UpdateType]::Source) {
                        $Change.DependsOn.Clear()
                        $Change.CommandObject | ConvertFrom-Json | Write-Output
                    }
                    continue
                }
                if ($Change.UpdateType -eq [UpdateType]::Source) {
                    Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] $($Change.Id) is a source change with no needed changes"
                    $Change.CommandObject | ConvertFrom-Json | Write-Output
                    continue
                }
                $changeCount++
                try {
                    Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] $($Change.ProcessInfo)"
                    if (!$ValidateOnly) {
                        Invoke-Command -ScriptBlock $Change.ProcessInfo -NoNewScope -ErrorAction Stop | Out-Null
                    }
                    if ($ValidateOnly -and $null -ne $ExecutionPlanPath) {
                        $Change.ProcessInfo.ToString() | Add-Content -Path $ExecutionPlanPath
                    }
                    [E911ModuleState]::ShouldClear = $true
                }
                catch {
                    $Change.CommandObject.Warning.Add([WarningType]::OnlineChangeError, "Command: { $($Change.ProcessInfo) } ErrorMessage: $($_.Exception.Message)")
                    Write-Warning "Command: { $($Change.ProcessInfo) } ErrorMessage: $($_.Exception.Message)"
                }
            }
        }
        $vsw.Stop()
        Write-Progress -Activity 'Processing changes' -Completed -Id $MyInvocation.PipelinePosition
        Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] Finished"
    }
}

# (imported from .\private\Reset-CsE911Cache.ps1)
function Reset-CsE911Cache {
    [CmdletBinding()]
    param()
    end {
        [E911ModuleState]::FlushCaches($null)
    }
}

Export-ModuleMember -Function Get-CsE911NeededChange
Export-ModuleMember -Function Get-CsE911OnlineConfiguration
Export-ModuleMember -Function Set-CsE911OnlineChange
Export-ModuleMember -Function Reset-CsE911Cache
