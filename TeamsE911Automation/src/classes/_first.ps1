enum WarningType {
    InvalidInput
    MapsValidation
    OnlineChangeError
}

class Warning {
    [WarningType]
    $Type
    [string]
    $Message
    Warning([string] $WarningString) {
        $Parts = $WarningString.Split(':',2)
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
        return $this.Type -eq $Other.Type -and $this.Message -eq $Other.Message
    }
}

class WarningList {
    $Items = [System.Collections.Generic.List[Warning]]::new()
    WarningList([string] $WarningListString) {
        if ([string]::IsNullOrEmpty($WarningListString)) {
            return
        }
        $Parts = $WarningListString.Split(';')
        foreach ($Part in $Parts) {
            $this.Items.Add([Warning]::new($Part.Trim()))
        }
    }
    [void] Add([Warning] $Warning) {
        if ($this.Items.Contains($Warning)) { return }
        $this.Items.Add($Warning)
    }
    [void] Add([WarningType] $Type, [string] $Message) {
        $Warning = [Warning]::new($Type, $Message)
        if ($this.Items.Contains($Warning)) { return }
        $this.Items.Add($Warning)
    }
    [void] Remove([Warning] $Warning) {
        $this.Items.Remove($Warning)
    }
    [string] ToString() {
        return ($this.Items -join ';')
    }
}

enum NetworkObjectType {
    Unknown
    Subnet
    Switch
    Port
    WirelessAccessPoint
}

class NetworkObjectIdentifier {
    [string] $PhysicalAddress
    [string] $PortId
    [System.Net.IPAddress] $SubnetId

    NetworkObjectIdentifier ([string] $NetworkObjectString) {
        if ([string]::IsNullOrEmpty($NetworkObjectString)) {
            return
        }
        $tryParts = $NetworkObjectString.Split(';')
        if ($tryParts.Count -eq 2){
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
            if ($addressParts.Count -ne 6) { throw }
            $address = $addressParts -join '-'
            if ($addressParts[-1].EndsWith('*') -and $addressParts[-1].Length -in @(1, 2)) {
                for ($i = 0; $i -lt ($addressParts.Count - 1); $i++) {
                    if ($addressParts[$i] -notmatch '^[A-F0-9]{2}$') { throw }
                }
                return $address
            }
            $pa = [Net.NetworkInformation.PhysicalAddress]::Parse($address)
            if ($pa) {
                return [BitConverter]::ToString($pa.GetAddressBytes())
            }
            throw
        }
        catch {
            return [string]::Empty
        }
    }
}

class NetworkObject {
    [NetworkObjectType] $Type
    [NetworkObjectIdentifier] $Identifier

    NetworkObject() {
        $this.Type = [NetworkObjectType]::Unknown
        $this.Identifier = [NetworkObjectIdentifier]::new([string]::Empty)
    }

    NetworkObject([NetworkObjectType]$type, [NetworkObjectIdentifier]$identifier) {
        $this.Type = $type
        $this.Identifier = $identifier
    }

    NetworkObject([string]$type, [string]$identifier) {
        $this.Type = [NetworkObjectType]$type
        $this.Identifier = [NetworkObjectIdentifier]::new($identifier)
    }

    [string] GetHash() {
        return [Hasher]::GetHash("$($this.NetworkObjectType)$($this.NetworkObjectIdentifier)")
    }
}

class Hasher {
    hidden static $_hashAlgorithm = [System.Security.Cryptography.HashAlgorithm]::Create('sha256')

    static [string] GetHash([string] $string) {
        return [Convert]::ToBase64String([Hasher]::_hashAlgorithm.ComputeHash([Text.Encoding]::UTF8.GetBytes($string)))
    }
}

class LocationRow {
    hidden [PSCustomObject] $_originalRow

    # hidden static [string] ConvertFromOnlineAddress([PSCustomObject]$Online) {
    #     $AddressKeys = @(
    #         "HouseNumber",
    #         "HouseNumberSuffix",
    #         "PreDirectional",
    #         "StreetName",
    #         "StreetSuffix",
    #         "PostDirectional"
    #     )
    #     $addressSb = [Text.StringBuilder]::new()
    #     foreach ($prop in $AddressKeys) {
    #         if (![string]::IsNullOrEmpty($Online.$prop)) {
    #             if ($addressSb.Length -gt 0) {
    #                 $addressSb.Append(' ') | Out-Null
    #             }
    #             $addressSb.Append($Online.$prop.Trim()) | Out-Null
    #         }
    #     }
    #     return $addressSb.ToString()
    # }

    hidden [bool] $HasChanged

    hidden [bool] CheckIfHasChanged([string] $ExistingHash) {
        $this.UpdateEntryHashes()
        return $ExistingHash -eq $this.EntryHash
    }

    hidden [string] $_string

    [string] ToString() {
        if ([string]::IsNullOrEmpty($this._string)) {
            $this._string = $this._originalRow | Select-Object -Property * -ExcludeProperty EntryHash | ConvertTo-Json -Compress
        }
        if ([string]::IsNullOrEmpty($this._string)) {
            $this._string = [string]::Empty
        }
        return $this._string
    }

    hidden [void] UpdateEntryHashes() {
        # has algo here to update all hashes (using the original object from above so as to detect string changes)
        $this.EntryHash = [Hasher]::GetHash($this.ToString())
        $PropsToHash = @(
            "Address"
            "City"
            "CompanyName"
            "CompanyTaxId"
            "CountryOrRegion"
            # "Location"
            "Description"
            "ELIN"
            "Latitude"
            "Longitude"
            "PostalCode"
            "SkipMapsLookup"
            "StateOrProvince"
        )
        $this._addressHash = [Hasher]::GetHash(($this | Select-Object -Property $PropsToHash | ConvertTo-Json -Compress))
        $this._locationHash = [Hasher]::GetHash(($this | Select-Object -Property 'Location' | ConvertTo-Json -Compress))
        $this._networkObjectHash = $this._networkObject.GetHash()
        $this._nonNetworkObjectHash = [Hasher]::GetHash("$($this._addressHash)$($this._locationHash)")
    }

    LocationRow() {
        $this._AddNetworkObjectType()
        $this._AddNetworkObjectIdentifier()
        $this.HasChanged = $true
        $this.UpdateEntryHashes()
    }

    LocationRow([PSCustomObject]$obj) {
        if ($obj.Properties.Where({$_.Name -eq 'StreetName'}).Count -gt 0) {
            throw [NotImplementedException]::new("Online conversion not yet implemented!")
        }
        $this._originalRow = $obj
        $this._AddNetworkObjectType()
        $this._AddNetworkObjectIdentifier()

        $this.Warning = [WarningList]::new($obj.Warning)
        $WarnType = [WarningType]::InvalidInput

        # all required
        $RequiredProps = @(
            "CompanyName",
            "Location",
            "Address",
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
        $this.CompanyName = $obj.CompanyName
        $this.Location = $obj.Location  # should we set this to a magic string (like DEFAULT_LOCATION) if it is empty to allow for use of the default location?
        $this.Address = $obj.Address -replace '\s+', ' '
        $this.City = $obj.City
        $this.StateOrProvince = $obj.StateOrProvince
        if ($obj.CountryOrRegion.Length -ne 2) {
            [void]$this.Warning.Add($WarnType, "CountryOrRegion not ISO 3166-1 alpha-2 code")
        }
        $this.CountryOrRegion = $obj.CountryOrRegion

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
        if ($this.SkipMapsLookup) {
            # these are now required
            if ([string]::IsNullOrWhiteSpace($obj.PostalCode)) {
                [void]$this.Warning.Add($WarnType, "PostalCode missing")
            }
        }

        $this.PostalCode = $obj.PostalCode
        $this.Latitude = $obj.Latitude
        $this.Longitude = $obj.Longitude
        $this.CompanyTaxId = $obj.CompanyTaxId
        $this.AddressDescription = $obj.AddressDescription
        $this.Description = $obj.Description
        $this.ELIN = $obj.ELIN

        $this.NetworkDescription = $obj.NetworkDescription

        try {
            $this.NetworkObjectType = [NetworkObjectType]"$(if([string]::IsNullOrWhiteSpace($obj.NetworkObjectType)){ 'Unknown' } else { $obj.NetworkObjectType })"
        }
        catch {
            [void]$this.Warning.Add($WarnType, "NetworkObjectType '$($obj.NetworkObjectType)'")
        }

        if ([string]::IsNullOrWhiteSpace($obj.NetworkObjectIdentifier) -and $this.NetworkObjectType -ne [NetworkObjectType]::Unknown) {
            [void]$this.Warning.Add($WarnType, "NetworkObjectIdentifier missing")
        }
        else {
            try {
                $this.NetworkObjectIdentifier = [NetworkObjectIdentifier]::new($obj.NetworkObjectIdentifier)
            }
            catch {
                [void]$this.Warning.Add($WarnType, "NetworkObjectIdentifier '$($obj.NetworkObjectIdentifier)'")
            }
        }
        # get new hash
        $this.HasChanged = $this.CheckIfHasChanged($obj.EntryHash)
    }

    [string] $CompanyName

    [AllowEmptyString()]
    [string] $CompanyTaxId

    [AllowEmptyString()]
    hidden [string] $AddressDescription

    [AllowEmptyString()]
    [string] $Description

    [string] $Location

    [string] $Address

    [string] $City

    [string] $StateOrProvince

    [AllowEmptyString()]
    [string] $PostalCode

    [ValidateLength(2,2)]
    [string] $CountryOrRegion

    [AllowNull()]
    [ValidateRange(-90.0, 90.0)]
    [double] $Latitude

    [AllowNull()]
    [ValidateRange(-180.0, 180.0)]
    [double] $Longitude

    [AllowEmptyString()]
    [string] $ELIN

    [AllowEmptyString()]
    [string] $NetworkDescription

    hidden [NetworkObject] $_networkObject

    hidden [void] _AddNetworkObjectType() {
        $this | Add-Member -Name NetworkObjectType -MemberType ScriptProperty -Value {
            if ($null -eq $this._networkObject) { $this._networkObject = [NetworkObject]::new() }
            return $this._networkObject.Type
        } -SecondValue {
            param ($value)
            if ($null -eq $this._networkObject) { $this._networkObject = [NetworkObject]::new() }
            $this._networkObject.Type = [NetworkObjectType]$value
        }
    }

    hidden [void] _AddNetworkObjectIdentifier() {
        $this | Add-Member -Name NetworkObjectIdentifier -MemberType ScriptProperty -Value {
            if ($null -eq $this._networkObject) { $this._networkObject = [NetworkObject]::new() }
            return $this._networkObject.Identifier
        } -SecondValue {
            param ($value)
            if ($null -eq $this._networkObject) { $this._networkObject = [NetworkObject]::new() }
            $this._networkObject.Identifier = [NetworkObjectIdentifier]::new($value)
        }
    }

    # override getter/setter to only track on object
    # [NetworkObjectType] $NetworkObjectType
    # hidden [void] set_NetworkObjectType([NetworkObjectType]$value) {
    #     if ($null -eq $this._networkObject) { $this._networkObject = [NetworkObject]::new() }
    #     $this._networkObject.Type = [NetworkObjectType]$value
    # }
    # hidden [NetworkObjectType] get_NetworkObjectType() {
    #     Write-Information "get_NetworkObjectType"
    #     if ($null -eq $this._networkObject) { $this._networkObject = [NetworkObject]::new() }
    #     return $this._networkObject.Type
    # }

    # [NetworkObjectIdentifier] $NetworkObjectIdentifier
    # hidden [void] set_NetworkObjectIdentifier([NetworkObjectIdentifier]$value) {
    #     if ($null -eq $this._networkObject) { $this._networkObject = [NetworkObject]::new() }
    #     $this._networkObject.Identifier = [NetworkObjectIdentifier]::new($value)
    # }
    # hidden [NetworkObjectIdentifier] get_NetworkObjectIdentifier() {
    #     Write-Information "get_NetworkObjectIdentifier"
    #     if ($null -eq $this._networkObject) { $this._networkObject = [NetworkObject]::new() }
    #     return $this._networkObject.Identifier
    # }

    [bool] $SkipMapsLookup = $false

    [WarningList] $Warning

    [string] $EntryHash

    hidden [string] $_networkObjectHash
    hidden [string] $_addressHash 
    hidden [string] $_locationHash
    hidden [string] $_nonNetworkObjectHash
}