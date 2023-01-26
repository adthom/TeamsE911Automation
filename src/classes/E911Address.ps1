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
    hidden [bool] $_commandGenerated

    hidden [void] Init([PSCustomObject] $obj, [bool]$ShouldValidate) {
        if (![string]::IsNullOrEmpty($obj.CivicAddressId)) {
            $this.Id = [ItemId]::new($obj.CivicAddressId)
        }
        else {
            $this.Id = [ItemId]::new()
        }
        $this.Warning = [WarningList]::new()
        $WarnType = [WarningType]::InvalidInput

        $this._commandGenerated = $false
        $addr = [E911Address]::_convertOnlineAddress($obj)
        $this._isOnline = $true
        $this._hasChanged = $false
        if ([string]::IsNullOrEmpty($addr)) {
            $addr = $obj.Address
            $this._isOnline = $false
        }
        if ([string]::IsNullOrEmpty($obj.CountryOrRegion) -and $this._isOnline) {
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
                [void]$this.Warning.Add($WarnType, "$(if([string]::IsNullOrEmpty($obj.Latitude)) { "Latitude" } else { "Longitude" }) missing")

            }
            if ($this.SkipMapsLookup -or ![string]::IsNullOrEmpty($obj.Latitude) -or ![string]::IsNullOrEmpty($obj.Longitude)) {
                $long = $null
                $lat = $null
                if (![string]::IsNullOrEmpty($obj.Longitude) -and ![double]::TryParse($obj.Longitude, [ref] $long) -or ($long -gt 180.0 -or $long -lt -180.0)) {
                    [void]$this.Warning.Add($WarnType, "Longitude '$($obj.Longitude)'")
                }
                if (![string]::IsNullOrEmpty($obj.Latitude) -and ![double]::TryParse($obj.Latitude, [ref] $lat) -or ($lat -gt 90.0 -or $lat -lt -90.0)) {
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
        if ([string]::IsNullOrEmpty($this.Elin)) { $this.Elin = '' }

        if ($ShouldValidate -and !$this.SkipMapsLookup) {
            [E911ModuleState]::ValidateAddress($this)
        }
    }

    E911Address ([PSCustomObject] $obj, [bool]$ShouldValidate) {
        $this.Init($obj, $ShouldValidate)
    }

    hidden E911Address() {}

    hidden E911Address([bool] $online) {
        $this._isOnline = $true
        $this._hasChanged = $false
        $this._commandGenerated = $false
        $this.Warning = [WarningList]::new()
    }

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

    [string] GetCommand() {
        if ($this._commandGenerated -or ($this._isOnline -and !$this._hasChanged)) {
            return ''
        }
        if ([string]::IsNullOrEmpty($this._command)) {
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
            [void]$sb.AppendFormat('$Addresses[''{0}''] = New-CsOnlineLisCivicAddress', $this.Id.VariableName())
            foreach ($Parameter in $AddressParams.Keys) {
                if ($AddressParams[$Parameter].ToString() -match '[''"\s|&<>@#\(\)\$;,`]') {
                    [void]$sb.AppendFormat(' -{0} ''{1}''', $Parameter, $AddressParams[$Parameter].ToString().Replace('''', ''''''))
                }
                else {
                    [void]$sb.AppendFormat(' -{0} {1}', $Parameter, $AddressParams[$Parameter])
                }
            }
            $sb.Append(' -ErrorAction Stop | Select-Object -Property CivicAddressId, DefaultLocationId')
            $this._command = $sb.ToString()
        }
        return $this._command
    }

    static [string] GetHash([PSCustomObject] $obj) {
        $addr = [E911Address]::_convertOnlineAddress($obj)
        if ([string]::IsNullOrEmpty($addr)) { $addr = $obj.Address }
        $addr = [E911ModuleState]::GetCleanAddressParts($addr) -join ' '
        $test = '{{"CompanyName":"{0}","Address":"{1}","City":"{2}","StateOrProvince":"{3}","PostalCode":"{4}","CountryOrRegion":"{5}"}}' -f $obj.CompanyName, $addr, $obj.City, $obj.StateOrProvince, $obj.PostalCode, $obj.CountryOrRegion
        # $test = [PSCustomObject]@{
        #     CompanyName     = $obj.CompanyName
        #     Address         = [E911ModuleState]::GetCleanAddressParts($addr) -join ' '
        #     City            = $obj.City
        #     StateOrProvince = $obj.StateOrProvince
        #     PostalCode      = $obj.PostalCode
        #     CountryOrRegion = $obj.CountryOrRegion
        # }
        # $Hash = [Hasher]::GetHash(($test | Select-Object -Property ([E911Address]::_addressHashProps) | ConvertTo-Json -Compress).ToLower())
        $Hash = [Hasher]::GetHash($test.ToLower())
        return $Hash
    }

    [string] GetHash() {
        if ([string]::IsNullOrEmpty($this._hash)) {
            $test = [PSCustomObject]@{
                # StreetName      = $this.Address
                Address         = $this.Address.Trim()
                CompanyName     = $this.CompanyName
                City            = $this.City
                StateOrProvince = $this.StateOrProvince
                PostalCode      = $this.PostalCode
                CountryOrRegion = $this.CountryOrRegion
            }
            $this._hash = [E911Address]::GetHash($test)
            # $this._hash = [Hasher]::GetHash(($this | Select-Object -Property ([E911Address]::_addressHashProps) | ConvertTo-Json -Compress).ToLower())
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
            if ((![string]::IsNullOrEmpty($Value1.Elin) -or ![string]::IsNullOrEmpty($Value2.Elin)) -and $Value1.Elin -ne $Value2.Elin) {
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
        $addressSb = [Text.StringBuilder]::new()
        if ($Online -is [E911Address] -or $Online -is [E911Location] -or $Online -is [E911NetworkObject]) {
            $null = $addressSb.Append($Online.Address.Trim())
        }
        else {
            $null = $addressSb.AppendJoin(' ', $Online.HouseNumber, $Online.HouseNumberSuffix, $Online.PreDirectional, $Online.StreetName, $Online.StreetSuffix, $Online.PostDirectional)
        }
        do {
            # remove all double spaces until there are no more
            $len = $addressSb.Length
            $null = $addressSb.Replace('  ', ' ')
        } while ($addressSb.Length -lt $len)
        return $addressSb.ToString().Trim()
    }
}
