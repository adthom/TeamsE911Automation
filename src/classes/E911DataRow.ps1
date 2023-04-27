class E911DataRow {
    hidden static [object[]] $Properties = @('CompanyName', 'CompanyTaxId', 'Description', 'Address', 'Location', 'City', 'StateOrProvince', 'PostalCode', 'CountryOrRegion', 'Latitude', 'Longitude', 'Elin', 'NetworkDescription', 'NetworkObjectType', 'NetworkObjectIdentifier', 'SkipMapsLookup')
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

    E911DataRow([hashtable]$hash) {
        $this.Init(([PSCustomObject]$hash), $false)
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
            return $true
        }
        return $this._networkObject._hasChanged -or $this._networkObject._location._hasChanged -or $this._networkObject._location._address._hasChanged
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

    [Collections.Generic.List[ChangeObject]] GetChangeCommands([PSFunctionHost]$parent) {
        $parent.WriteVerbose('Getting Commands...')
        $l = [Collections.Generic.List[ChangeObject]]::new()
        $GetCommands = $true
        if (!$this.NeedsUpdate() -and (!$this.HasChanged() -and ![E911ModuleState]::ForceOnlineCheck)) {
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
                $parent.WriteVerbose('Address new or changed')
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
                $parent.WriteVerbose('Location new or changed')
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
                $parent.WriteVerbose('Network Object new or changed!')
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
                Property = [E911DataRow]::Properties
            }
            $this._hashString = $this._originalRow | Select-Object @SelectParams | ConvertTo-Json -Compress
        }
        return $this._hashString
    }
    [string] ToString() {
        $SelectParams = @{
            Property = [E911DataRow]::Properties + @(
                @{ Name = 'EntryHash'; Expression = { $this.EntryHash } }, 
                @{ Name = 'Warning'; Expression = { if ($this.HasWarnings()) { $this.Warning.ToString() } else { '' } } }
            )
        }
        $this._string = $this._originalRow | Select-Object @SelectParams | ConvertTo-Json -Compress
        $this._lastWarnCount = $this.Warning.Count()
        return $this._string
    }

    [string] GetHash() {
        if ([string]::IsNullOrEmpty($this._hash)) {
            $this._hash = [E911DataRow]::GetHash($this._originalRow)
        }
        return $this._hash
    }

    static [string] GetHash([object] $obj) {
        $SelectParams = @{
            Property = [E911DataRow]::Properties
        }
        $hashString = $obj | Select-Object @SelectParams | ConvertTo-Json -Compress
        return [Hasher]::GetHash($hashString)
    }

    static E911DataRow() {
        $CustomProperties = @(
            @{
                Name  = 'CompanyName' 
                Value = { return $this._networkObject._location.CompanyName }
            },
            @{
                Name  = 'CompanyTaxId'
                Value = { return $this._networkObject._location.CompanyTaxId }
            }
            @{
                Name  = 'Description'
                Value = { return $this._networkObject._location.Description }
            }
            @{
                Name  = 'Address'
                Value = { return $this._networkObject._location.Address }
            }
            @{
                Name  = 'Location'
                Value = { return $this._networkObject._location.Location }
            }
            @{
                Name  = 'City'
                Value = { return $this._networkObject._location.City }
            }
            @{
                Name  = 'StateOrProvince'
                Value = { return $this._networkObject._location.StateOrProvince }
            }
            @{
                Name  = 'PostalCode'
                Value = { return $this._networkObject._location.PostalCode }
            }
            @{
                Name  = 'CountryOrRegion'
                Value = { return $this._networkObject._location.CountryOrRegion }
            }
            @{
                Name  = 'Latitude'
                Value = { return $this._networkObject._location.Latitude }
            }
            @{
                Name  = 'Longitude'
                Value = { return $this._networkObject._location.Longitude }
            }
            @{
                Name  = 'ELIN'
                Value = { return $this._networkObject._location.Elin }
            }
            @{
                Name  = 'NetworkDescription'
                Value = { return $this._networkObject.Description }
            }
            @{
                Name  = 'NetworkObjectType'
                Value = { return $this._networkObject.Type }
            }
            @{
                Name  = 'NetworkObjectIdentifier'
                Value = { return $this._networkObject.Identifier }
            }
            @{
                Name  = 'EntryHash'
                Value = { return $this.GetHash() }
            }
        )

        $Type = [E911DataRow]
        foreach ($CustomProperty in $CustomProperties) {
            $TypeDataParams = @{
                MemberName = $CustomProperty['Name']
                MemberType = 'ScriptProperty' 
                Value      = $CustomProperty['Value']
                Force      = $true
            }
            $Type | Update-TypeData @TypeDataParams
        }
    }
}
