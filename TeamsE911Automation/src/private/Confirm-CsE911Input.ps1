function Confirm-CsE911Input {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [PSObject]
        $LocationInput
    )

    $Manditory = @(
        "CompanyName",
        "Location",
        "Address",
        "City",
        "StateOrProvince",
        "CountryOrRegion"
    )

    $NetworkObjectTypes = @(
        "WirelessAccessPoint"
        "Port"
        "Switch"
        "Subnet"
    )

    # ensure validation for all fields if SkipMapsLookup override is set
    try {
        if (![string]::IsNullOrWhiteSpace($LocationInput.SkipMapsLookup) -and [System.Convert]::ToBoolean($LocationInput.SkipMapsLookup)) {
            $Manditory = @(
                "CompanyName"
                "Address"
                "City"
                "StateOrProvince"
                "PostalCode"
                "CountryOrRegion"
                "Latitude"
                "Longitude"
            )
        }
    }
    catch {
        Write-Warning "InvalidInput: SkipMapsLookup is not a valid boolean"
        return $false
    }

    # check for manditory fields:
    foreach ($mProp in $Manditory) {
        if ([string]::IsNullOrWhiteSpace($LocationInput.$mProp)) {
            Write-Warning "InvalidInput: MissingRequiredField: $mProp"
            return $false
        }
    }

    if ($LocationInput.CountryOrRegion.Length -ne 2) {
        Write-Warning "InvalidInput: CountryOrRegion not ISO 3166-1 alpha-2 code"
        return $false
    }

    if (![string]::IsNullOrEmpty($LocationInput.Longitude) -xor ![string]::IsNullOrEmpty($LocationInput.Latitude)) {
        # only one provided of lat or long, both are required if either is present
        Write-Warning "InvalidInput: Invalid Latitude/Longitude"
        return $false
    }
    elseif (!([string]::IsNullOrEmpty($LocationInput.Longitude) -and [string]::IsNullOrEmpty($LocationInput.Latitude))) {
        # make sure lat or long is valid
        # longitude: -180 to 180
        $Longitude = $null
        if (![double]::TryParse($LocationInput.Longitude, [ref] $Longitude) -or ($Longitude -gt 180.0 -or $Longitude -lt -180.0)) {
            Write-Warning "InvalidInput: Invalid Longitude"
            return $false
        }
        # latitude: -90 to 90
        $Latitude = $null
        if (![double]::TryParse($LocationInput.Latitude, [ref] $Latitude) -or ($Latitude -gt 90.0 -or $Latitude -lt -90.0)) {
            Write-Warning "InvalidInput: Invalid Latitude"
            return $false
        }
    }

    if ($LocationInput.NetworkObjectType -notin $NetworkObjectTypes) {
        Write-Warning "InvalidInput: NetworkObjectType: $($LocationInput.NetworkObjectType) is not in $($NetworkObjectTypes -join ',')"
        return $false
    }

    if ([string]::IsNullOrEmpty($LocationInput.NetworkObjectIdentifier)) {
        Write-Warning "InvalidInput: NetworkObjectIdentifier is missing"
        return $false
    }

    switch ($LocationInput.NetworkObjectType) {
        "WirelessAccessPoint" {
            $valid = ConvertTo-PhysicalAddressString -address $LocationInput.NetworkObjectIdentifier
            if (!$valid) {
                Write-Warning "InvalidInput: BSSID"
            }
            return $valid
        }
        "Subnet" {
            $valid = [IPAddress]::TryParse($LocationInput.NetworkObjectIdentifier, [ref] $null)
            if (!$valid) {
                Write-Warning "InvalidInput: Subnet"
            }
            return $valid
        }
        "Port" {
            $ChassisId, $PortId = $LocationInput.NetworkObjectIdentifier -split ';', 2
            $ChassisIdValid = (ConvertTo-PhysicalAddressString -address $ChassisId) -or $ChassisId.Length -lt 512
            $valid = (ConvertTo-PhysicalAddressString -address $PortId) -or $PortId.Length -lt 512 -and $ChassisIdValid
            if (!$valid) {
                Write-Warning "InvalidInput: PortId or ChassisId"
            }
            return $valid
        }
        "Switch" {
            $valid = (ConvertTo-PhysicalAddressString -address $LocationInput.NetworkObjectIdentifier) -or $LocationInput.NetworkObjectIdentifier.Length -lt 512
            if (!$valid) {
                Write-Warning "InvalidInput: ChassisId"
            }
            return $valid
        }
    }
}
