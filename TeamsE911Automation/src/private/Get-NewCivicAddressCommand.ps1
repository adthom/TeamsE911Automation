function Get-NewCivicAddressCommand {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object]
        $NetworkObject,

        [Parameter(Mandatory = $true)]
        [string]
        $CivicAddressIdVariableName
    )
    process {
        if (![string]::IsNullOrWhiteSpace($NetworkObject.SkipMapsLookup) -and [System.Convert]::ToBoolean($NetworkObject.SkipMapsLookup)) {
            Write-Verbose "Skipping Azure Maps Validation..."
            $HouseNumber = $NetworkObject.Address -replace '^.*?(\d+\S*)\s+.*$', '$1'
            $StreetName = $NetworkObject.Address -replace [regex]::Escape($HouseNumber), ''

            $AddressParams = @{
                HouseNumber     = $HouseNumber
                StreetName      = $StreetName.Trim()
                City            = $NetworkObject.City
                StateOrProvince = $NetworkObject.StateOrProvince
                CompanyName     = $NetworkObject.CompanyName
                PostalCode      = $NetworkObject.PostalCode
                Country         = $NetworkObject.CountryOrRegion
                Latitude        = $NetworkObject.Latitude
                Longitude       = $NetworkObject.Longitude
            }

            if ($NetworkObject.Description) {
                $AddressParams['Description'] = $NetworkObject.Description
            }
            if ($NetworkObject.CompanyTaxId) {
                $AddressParams['CompanyTaxId'] = $NetworkObject.CompanyTaxId
            }
        }
        else {
            $AzureMapsParams = @{
                Address = $NetworkObject.Address
            }
            if ($NetworkObject.City) {
                $AzureMapsParams['City'] = $NetworkObject.City
            }
            if ($NetworkObject.StateOrProvince) {
                $AzureMapsParams['StateOrProvince'] = $NetworkObject.StateOrProvince
            }
            if ($NetworkObject.PostalCode) {
                $AzureMapsParams['PostalCode'] = $NetworkObject.PostalCode
            }
            if ($NetworkObject.CountryOrRegion) {
                $AzureMapsParams['CountryOrRegion'] = $NetworkObject.CountryOrRegion
            }
            $AzureMapsAddress = Get-AzureMapsValidAddress @AzureMapsParams

            $Warned = $false
            # write warnings for changes from input
            $AzureAddress = "{0} {1}" -f $AzureMapsAddress.HouseNumber, $AzureMapsAddress.StreetName
            if ($NetworkObject.Address -ne $AzureAddress) {
                Write-Warning "MapsValidation: Provided Address: '$($NetworkObject.Address)' does not match Azure Maps Address: '$($AzureAddress)'!"
                $Warned = $true
            }
            if ($NetworkObject.City -ne $AzureMapsAddress.City) {
                Write-Warning "MapsValidation: Provided City: '$($NetworkObject.City)' does not match Azure Maps City: '$($AzureMapsAddress.City)'!"
                $Warned = $true
            }
            if ($NetworkObject.StateOrProvince -ne $AzureMapsAddress.StateOrProvince) {
                Write-Warning "MapsValidation: Provided StateOrProvince: '$($NetworkObject.StateOrProvince)' does not match Azure Maps StateOrProvince: '$($AzureMapsAddress.StateOrProvince)'!"
                $Warned = $true
            }
            if ($NetworkObject.PostalCode -ne $AzureMapsAddress.PostalCode) {
                Write-Warning "MapsValidation: Provided PostalCode: '$($NetworkObject.PostalCode)' does not match Azure Maps PostalCode: '$($AzureMapsAddress.PostalCode)'!"
                $Warned = $true
            }
            if ($NetworkObject.CountryOrRegion -ne $AzureMapsAddress.Country) {
                Write-Warning "MapsValidation: Provided Country: '$($NetworkObject.CountryOrRegion)' does not match Azure Maps Country: '$($AzureMapsAddress.Country)'!"
                $Warned = $true
            }
            if ($NetworkObject.Latitude -ne 0 -and $NetworkObject.Longitude -ne 0) {
                if (!(Compare-DoubleFuzzy $NetworkObject.Latitude $AzureMapsAddress.Latitude)) {
                    Write-Warning "MapsValidation: Provided Latitude: '$($NetworkObject.Latitude)' does not match Azure Maps Latitude: '$($AzureMapsAddress.Latitude)'!"
                    $Warned = $true
                }
                if (!(Compare-DoubleFuzzy $NetworkObject.Longitude $AzureMapsAddress.Longitude)) {
                    Write-Warning "MapsValidation: Provided Longitude: '$($NetworkObject.Longitude)' does not match Azure Maps Longitude: '$($AzureMapsAddress.Longitude)'!"
                    $Warned = $true
                }
            }
            if ($Warned) {
                Write-Warning "MapsValidationDetail: AzureMapsAddress: $($AzureMapsAddress | ConvertTo-Json -Compress)"
            }

            $AddressParams = @{
                StreetName      = $AzureMapsAddress.StreetName
                City            = $AzureMapsAddress.City
                StateOrProvince = $AzureMapsAddress.StateOrProvince
                CompanyName     = $NetworkObject.CompanyName
            }
            if ($AzureMapsAddress.HouseNumber) {
                $AddressParams['HouseNumber'] = $AzureMapsAddress.HouseNumber
            }
            if ($NetworkObject.Description) {
                $AddressParams['Description'] = $NetworkObject.Description
            }
            if ($NetworkObject.CompanyTaxId) {
                $AddressParams['CompanyTaxId'] = $NetworkObject.CompanyTaxId
            }
            if ($AzureMapsAddress.PostalCode) {
                $AddressParams['PostalCode'] = $AzureMapsAddress.PostalCode
            }
            if ($AzureMapsAddress.Country) {
                $AddressParams['Country'] = $AzureMapsAddress.Country
            }
            if ($AzureMapsAddress.Latitude -and $AzureMapsAddress.Longitude) {
                $AddressParams['Latitude'] = $AzureMapsAddress.Latitude
                $AddressParams['Longitude'] = $AzureMapsAddress.Longitude
            }
        }

        $AddressCommand = "{0} = New-CsOnlineLisCivicAddress -ErrorAction Stop" -f $CivicAddressIdVariableName
        foreach ($Parameter in $AddressParams.Keys) {
            $AddressCommand += ' -{0} "{1}"' -f $Parameter, ($AddressParams[$Parameter] -replace , '"', '`"')
        }
        $AddressCommand | Write-Output
    }
}
