function Get-CsE911CivicAddressHashCode {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [PSObject]
        $Address
    )

    $addressHashProps = @(
        "CompanyName",
        "Address",
        "City",
        "StateOrProvince",
        "PostalCode",
        "Country"
    )
    $hashSb = [Text.StringBuilder]::new()
    foreach ($prop in $addressHashProps) {
        if (![string]::IsNullOrEmpty($Address.$prop)) {
            $hashSb.Append($Address.$prop.ToLower().Trim()) | Out-Null
        }
    }
    return (Get-StringHash -String $hashSb.ToString())
}
