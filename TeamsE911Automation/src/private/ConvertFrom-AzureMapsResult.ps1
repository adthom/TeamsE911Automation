function ConvertFrom-AzureMapsResult {
    [CmdletBinding()]
    [OutputType([PSObject])]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [Object[]]
        $Results
    )

    process {
        $Address = $Results | Sort-Object -Property score -Descending | Where-Object { $_.type -in @('Point Address', 'Address Range') } | Select-Object -First 1
        if ($null -eq $Address) {
            return
        }
        Write-Verbose "Found result of type $($Address.type)"
        return [PSCustomObject]@{
            HouseNumber     = $Address.address.streetNumber
            StreetName      = ($Address.address.streetName -split ',')[0]
            City            = ($Address.address.municipality -split ',')[0]
            StateOrProvince = $Address.address.countrySubdivision
            PostalCode      = Get-CsE911PostalOrZipCode -ExtendedPostalCode $Address.address.extendedPostalCode -PostalCode $Address.address.postalCode -CountryCode $Address.address.countryCode
            Country         = $Address.address.countryCode
            Latitude        = $Address.position.lat
            Longitude       = $Address.position.lon
        }
    }
}
