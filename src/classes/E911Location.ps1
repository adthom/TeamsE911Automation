class E911Location {
    hidden [ItemId] $Id
    hidden [bool] $_isOnline
    hidden [bool] $_hasChanged
    hidden [bool] $_isDefault
    hidden [bool] $_commandGenerated
    hidden [string] $_hash
    hidden [string] $_command
    hidden [E911Address] $_address

    E911Location ([PSCustomObject] $obj, [bool] $ShouldValidate) {
        if (![string]::IsNullOrEmpty($obj.LocationId) -and ![string]::IsNullOrEmpty($obj.CountryOrRegion)) {
            # made via online location
            $this._isOnline = $true
            $this.Id = [ItemId]::new($obj.LocationId)
        }
        elseif (![string]::IsNullOrEmpty($obj.DefaultLocationId)) {
            # if location is made via civicaddress
            $this._isOnline = $true
            $this.Id = [ItemId]::new($obj.DefaultLocationId)
        }
        else {
            # new entry for location
            $this._isOnline = $false
            $this.Id = [ItemId]::new()
        }

        $this._isDefault = [string]::IsNullOrEmpty($obj.Location)
        $this._hasChanged = $false
        $this._commandGenerated = $false
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
        if (![string]::IsNullOrEmpty($obj.CivicAddressId) -and $this._address.Id.ToString().ToLower() -ne $obj.CivicAddressId.ToLower()) {
            # re-home this object to the other matching address id
            $this._hasChanged = $true
        }

        $this.Location = $obj.Location
        if ([string]::IsNullOrEmpty($this.Location)) { $this.Location = '' }
        $this.Elin = $obj.Elin
        if ([string]::IsNullOrEmpty($this.Elin)) { $this.Elin = '' }
        if ($this._address.DefaultLocationId -eq $this.Id.ToString() -and $this._address.Elin -ne $this.Elin) {
            # Elin conflict, must be recreated
            $this._hasChanged = $true
            $this._address._hasChanged = $true
            $this._address.Elin = $this.Elin
        }
    }

    hidden E911Location() {}

    hidden E911Location([bool] $online) {
        $this._isOnline = $true
        $this._hasChanged = $false
        $this._commandGenerated = $false
        $this.Warning = [WarningList]::new()
    }

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
        if ($this._commandGenerated -or ($this._isOnline -and !$this._hasChanged) -or $this._isDefault) {
            return ''
        }
        $sb = [Text.StringBuilder]::new()
        if ($this._address._isOnline -and !$this._address._hasChanged) {
            $CivicAddressId = '{0}' -f $this._address.Id.ToString()
        }
        else {
            $CivicAddressId = '$Addresses[''{0}''].CivicAddressId' -f $this._address.Id.VariableName()
        }
        $LocationParams = @{
            CivicAddressId = $CivicAddressId
            Location       = '{0}' -f $this.Location
        }
        if (![string]::IsNullOrEmpty($this.Elin)) {
            $LocationParams['Elin'] = '{0}' -f $this.Elin
        }
        [void]$sb.AppendFormat('$Locations[''{0}''] = New-CsOnlineLisLocation', $this.Id.VariableName())
        foreach ($Parameter in $LocationParams.Keys) {
            if ($LocationParams[$Parameter].ToString() -match '[''"\s|&<>@#\(\)\$;,`]' -and $Parameter -ne 'CivicAddressId') {
                [void]$sb.AppendFormat(' -{0} ''{1}''', $Parameter, $LocationParams[$Parameter].ToString().Replace('''', ''''''))
            }
            else {
                [void]$sb.AppendFormat(' -{0} {1}', $Parameter, $LocationParams[$Parameter])
            }
        }
        $sb.Append(' -ErrorAction Stop | Select-Object -Property LocationId')
        return $sb.ToString()
    }

    static [string] GetHash([PSCustomObject] $obj) {
        $LString = "$($obj.Location)$($obj.Elin)".ToLower()
        $AHash = [E911Address]::GetHash($obj)
        return [Hasher]::GetHash("${AHash}${LString}")
    }

    [string] GetHash() {
        if ([string]::IsNullOrEmpty($this._hash)) {
            $this._hash = [E911Location]::GetHash($this)
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

    static E911Location() {
        $CustomProperties = @(
            @{
                Name  = 'CompanyName'
                Value = { return $this._address.CompanyName }
            }
            @{
                Name  = 'CompanyTaxId'
                Value = { return $this._address.CompanyTaxId }
            }
            @{
                Name  = 'Description'
                Value = { return $this._address.Description }
            }
            @{
                Name  = 'Address'
                Value = { return $this._address.Address }
            }
            @{
                Name  = 'City'
                Value = { return $this._address.City }
            }
            @{
                Name  = 'StateOrProvince'
                Value = { return $this._address.StateOrProvince }
            }
            @{
                Name  = 'PostalCode'
                Value = { return $this._address.PostalCode }
            }
            @{
                Name  = 'CountryOrRegion'
                Value = { return $this._address.CountryOrRegion }
            }
            @{
                Name  = 'Latitude'
                Value = { return $this._address.Latitude }
            }
            @{
                Name  = 'Longitude'
                Value = { return $this._address.Longitude }
            }
        )

        $Type = [E911Location]
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
