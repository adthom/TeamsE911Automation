function Get-CsE911RowHash {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [object]
        $Row
    )
    $PropsToHash = @(
        "Address"
        "City"
        "CompanyName"
        "CompanyTaxId"
        "CountryOrRegion"
        "Description"
        "ELIN"
        "Latitude"
        "Location"
        "Longitude"
        "NetworkDescription"
        "NetworkObjectIdentifier"
        "NetworkObjectType"
        "PostalCode"
        "SkipMapsLookup"
        "StateOrProvince"
    )

    $RowStringToHash = if ($null -eq $Row) {
        [string]::Empty
    }
    else {
        $Row | Select-Object -Property $PropsToHash | ConvertTo-Json -Compress
    }
    return Get-StringHash -String $RowStringToHash
}
