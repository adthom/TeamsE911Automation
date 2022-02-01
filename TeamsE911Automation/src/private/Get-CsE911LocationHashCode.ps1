function Get-CsE911LocationHashCode {
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [PSObject]
        $Address,

        [Parameter(Mandatory = $true, Position = 1)]
        [AllowEmptyString()]
        [string]
        $Location
    )
    $addressHashCode = Get-CsE911CivicAddressHashCode($Address)
    $locationHash = "{0}{1}" -f $addressHashCode, $Location
    return (Get-StringHash -String $locationHash)
}
