class E911NetworkObject {
    hidden [ItemId] $Id
    hidden [bool] $_isOnline
    hidden [bool] $_hasChanged
    hidden [bool] $_isDuplicate
    hidden [bool] $_commandGenerated
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
        if ($null -eq $this.Warning) {
            $this.Warning = [WarningList]::new()
        }
        if ($null -ne $this._location -and $null -ne $this._location.Warning -and $this._location.Warning.HasWarnings()) {
            $this.Warning.AddRange($this._location.Warning)
        }
        $this.Id = [ItemId]::new()
        $this._isDuplicate = $false
        $this._hasChanged = $this._hasChanged -or $false
        $this._commandGenerated = $false
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
        $this._location = [E911ModuleState]::GetOrCreateLocation($obj, $ShouldValidate)
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
        $this._location = [E911ModuleState]::GetOrCreateLocation($obj, $false)
        if ([string]::IsNullOrEmpty($this._location.CountryOrRegion)) {
            $this._isOnline = $false
        }
        if (![string]::IsNullOrEmpty($this._locationId) -and $this._location.Id.ToString() -ne $this._locationId) {
            # re-home this object to the other matching location id
            $this._hasChanged = $true
        }
        $this.Init($newType, $newIdentifier, $obj.Description)
    }

    E911NetworkObject([PSCustomObject]$obj, [bool] $ShouldValidate) {
        if (![string]::IsNullOrEmpty($obj.LocationId)) {
            $this.Init($obj)
            return
        }
        $this.Init($obj, $ShouldValidate)
    }

    [NetworkObjectType] $Type
    [NetworkObjectIdentifier] $Identifier
    [string] $Description

    [WarningList] $Warning

    [string] GetCommand() {
        if ($this._commandGenerated -or ($this._isOnline -and !$this._hasChanged) -or $this.Type -eq [NetworkObjectType]::Unknown -or $null -eq $this._location) {
            return ''
        }
        if ([string]::IsNullOrEmpty($this._command)) {
            $sb = [Text.StringBuilder]::new()
            if ($this._location._isDefault -and $this._location._address._hasChanged) {
                $LocationId = '{0}.DefaultLocationId' -f $this._location._address.Id.VariableName()
            }
            elseif ($this._location._hasChanged) {
                $LocationId = '{0}.LocationId' -f $this._location.Id.VariableName()
            }
            else {
                $LocationId = '"{0}"' -f $this._location.Id.ToString()
            }
            [void]$sb.AppendFormat('$null = Set-CsOnlineLis{0} -LocationId {1}', $this.Type, $LocationId)
            if (![string]::IsNullOrEmpty($this.Description)) {
                [void]$sb.AppendFormat(' -Description "{0}"', $this.Description)
            }
            if ($this.Type -eq [NetworkObjectType]::Switch -or $this.Type -eq [NetworkObjectType]::Port) {
                [void]$sb.AppendFormat(' -ChassisId "{0}"', $this.Identifier.PhysicalAddress)
            }
            if ($this.Type -eq [NetworkObjectType]::Port) {
                [void]$sb.AppendFormat(' -PortId "{0}"', $this.Identifier.PortId)
            }
            if ($this.Type -eq [NetworkObjectType]::Subnet) {
                [void]$sb.AppendFormat(' -Subnet "{0}"', $this.Identifier.SubnetId.ToString())
            }
            if ($this.Type -eq [NetworkObjectType]::WirelessAccessPoint) {
                [void]$sb.AppendFormat(' -Bssid "{0}"', $this.Identifier.PhysicalAddress)
            }
            [void]$sb.Append(' -ErrorAction Stop')
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
        if ($D1 -ne $D2) {
            return $false
        }
        # see if locations are the same
        # if Value1 is row
        $LocationsEqual = if ($null -eq $Value1.LocationId -and $Value1 -isnot [E911NetworkObject]) {
            # if Value2 is row
            if ($null -eq $Value2.LocationId -and $Value2 -isnot [E911NetworkObject]) {
                [E911Location]::Equals($Value1, $Value2)
            }
            # if Value2 is network object
            elseif ($Value2 -is [E911NetworkObject]) {
                [E911Location]::Equals($Value1, $Value2._location)
            }
            # if Value2 is online
            else { 
                # cannot compare online network object to row on anything other than hash... or should we see if the online location exists (that would be expensive)
                throw "(Value2 is online) cannot compare online network object to row network object effectively"
            }
        }
        # if Value1 is network object
        elseif ($Value1 -is [E911NetworkObject]) {
            # if Value2 is row
            if ($null -eq $Value2.LocationId -and $Value2 -isnot [E911NetworkObject]) {
                [E911Location]::Equals($Value1._location, $Value2)
            }
            # if Value2 is network object
            elseif ($Value2 -is [E911NetworkObject]) {
                $Value1._location.Equals($Value2._location)
            }
            # if Value2 is online
            else {
                $Value1.Id.ToString() -eq $Value2.LocationId
            }
        }
        # if Value1 is online
        else {
            # if Value2 is row
            if ($null -eq $Value2.LocationId -and $Value2 -isnot [E911NetworkObject]) {
                # cannot compare online network object to row on anything other than hash... or should we see if the online location exists (that would be expensive)
                throw "(Value2 is row) cannot compare online network object to row network object effectively"
            }
            # if Value2 is network object
            elseif ($Value2 -is [E911NetworkObject]) {
                $Value1.LocationId -eq $Value2.Id.ToString()
            }
            # if Value2 is online
            else { 
                $Value1.LocationId -eq $Value2.LocationId
            }
        }

        return $LocationsEqual
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
