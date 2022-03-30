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
