function ConvertTo-CsE911Address {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [PSObject]
        $LisAddress
    )
    $addressString = ConvertTo-CsE911AddressString -CivicAddress $LisAddress
    $address = [PSCustomObject]@{
        CompanyName     = $LisAddress.CompanyName
        Address         = $AddressString
        City            = $LisAddress.City
        StateOrProvince = $LisAddress.StateOrProvince
        PostalCode      = $LisAddress.PostalCode
        Country         = $LisAddress.Country
    }
    return $address
}
