function ConvertTo-CsE911AddressString {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [PSObject]
        $CivicAddress
    )

    $AddressKeys = @(
        "HouseNumber",
        "HouseNumberSuffix",
        "PreDirectional",
        "StreetName",
        "StreetSuffix",
        "PostDirectional"
    )
    $addressSb = [Text.StringBuilder]::new()
    foreach ($prop in $AddressKeys) {
        if (![string]::IsNullOrEmpty($CivicAddress.$prop)) {
            if ($addressSb.Length -gt 0) {
                $addressSb.Append(' ') | Out-Null
            }
            $addressSb.Append($CivicAddress.$prop.Trim()) | Out-Null
        }
    }
    return $addressSb.ToString()
}
