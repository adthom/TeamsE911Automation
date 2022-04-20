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
    hidden [void] Init([PSCustomObject] $obj, [bool]$ForceSkipValidation) {
        $this._originalRow = $obj
        $this.Warning = [WarningList]::new($obj.Warning)

        $ShouldValidate = !$ForceSkipValidation -and ($this.HasChanged() -or [E911ModuleState]::ForceOnlineCheck)
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
        $this.Init($null, $false)
    }

    E911DataRow([PSCustomObject]$obj) {
        $this.Init($obj, $false)
    }

    E911DataRow([PSCustomObject]$obj, [bool] $ForceSkipValidation) {
        $this.Init($obj, $ForceSkipValidation)
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
        }
        if ($this.HasWarnings()) {
            $GetCommands = $false
        }
        $d = [DependsOn]::new()
        if ($GetCommands) {
            $ac = $this._networkObject._location._address.GetCommand()
            $addressAdded = $false
            if (![string]::IsNullOrEmpty($ac)) {
                $addressAdded = $true
                Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$CommandName] $($this.RowName()): Address new or changed!"
                $l.Add([ChangeObject]@{
                        UpdateType    = [UpdateType]::Online
                        ProcessInfo   = $ac
                        DependsOn     = $d
                        CommandType   = [CommandType]::Address
                        CommandObject = $this._networkObject._location._address
                    })
                
            }
            if ($addressAdded -or $this._networkObject._location._address._commandGenerated) {
                $d.Add($this._networkObject._location._address.Id)
            }
            $lc = $this._networkObject._location.GetCommand()
            $locationAdded = $false
            if (![string]::IsNullOrEmpty($lc)) {
                $locationAdded = $true
                Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$CommandName] $($this.RowName()): Location new or changed!"
                $l.Add([ChangeObject]@{
                        UpdateType    = [UpdateType]::Online
                        ProcessInfo   = $lc
                        DependsOn     = $d
                        CommandType   = [CommandType]::Location
                        CommandObject = $this._networkObject._location
                    })
            }
            if ($locationAdded -or $this._networkObject._location._commandGenerated) {
                $d.Add($this._networkObject._location.Id)
            }
            $nc = $this._networkObject.GetCommand()
            $networkAdded = $false
            if (![string]::IsNullOrEmpty($nc)) {
                $networkAdded = $false
                Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$CommandName] $($this.RowName()): Network Object new or changed!"
                $l.Add([ChangeObject]@{
                        UpdateType    = [UpdateType]::Online
                        ProcessInfo   = $nc
                        DependsOn     = $d
                        CommandType   = [CommandType]::NetworkObject
                        CommandObject = $this._networkObject
                    })
            }
            if ($networkAdded -or $this._networkObject._commandGenerated) {
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
