function Get-CsE911PostalOrZipCode {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Position = 0)]
        [string]
        $PostalCode,

        [Parameter(Position = 1)]
        [string]
        $ExtendedPostalCode,

        [Parameter(Position = 2)]
        [string]
        $CountryCode
    )

    $PostalOrZipCode = switch ($CountryCode) {
        { $_ -in @("CA", "IE", "GB", "PT") } {
            if ([string]::IsNullOrEmpty($ExtendedPostalCode)) {
                $PostalCode
            }
            else {
                $ExtendedPostalCode
            }
        }
        default {
            $PostalCode
        }
    }

    return $PostalOrZipCode
}
