# using module ..\..\modules\PSClassExtensions\bin\debug\PSClassExtensions
# WarningType
# E911Address
# AddressFormatter
# PSClassProperty

using namespace System.Web
using namespace System.Text
using namespace System.Text.RegularExpressions
using namespace System.Net.Http
using namespace System.Collections.Generic

class AddressValidator {
    [AddressFormatter] $Formatter = [AddressFormatter]::Default

    [bool] TestIsAddressMatch([string] $ReferenceAddress, [string] $DifferenceAddress) {
        if ($ReferenceAddress -eq $DifferenceAddress) { return $true }

        $ReferenceAddressTokens = $this.Formatter.TokenizeStreetAddress($ReferenceAddress)
        $ReferenceMatched = [bool[]]::new($ReferenceAddressTokens.Count)

        $DifferenceAddressTokens = $this.Formatter.TokenizeStreetAddress($DifferenceAddress)
        $DifferenceMatched = [bool[]]::new($DifferenceAddressTokens.Count)
        # simple match first
        for ($i = 0; $i -lt $ReferenceAddressTokens.Count; $i++) {
            if ($ReferenceMatched[$i]) { continue } # already matched, skip
            if (($Index = $DifferenceAddressTokens.IndexOf($ReferenceAddressTokens[$i])) -gt -1 -and !$DifferenceMatched[$Index]) {
                $ReferenceMatched[$i] = $true
                $DifferenceMatched[$Index] = $true
                continue
            }
        }
        $RefUnmatched = $ReferenceMatched.Where({ !$_ }).Count
        $DiffUnmatched = $DifferenceMatched.Where({ !$_ }).Count
        if ($RefUnmatched -eq 0 -and $DiffUnmatched -eq 0) {
            return $true
        }
        return $false
    }

    [void] ValidateAddress([E911Address] $Address) {
        if ($null -eq $this.MapsKey) {
            $Address.Warning.Add([WarningType]::MapsValidation, 'No Maps API Key Found')
            return
        }
        $QueryArgs = [ordered]@{
            'subscription-key' = $this.MapsKey
            'api-version'      = '1.0'
            query              = $this._getAddressInMapsQueryForm($Address)
            limit              = 10
            countrySet         = $Address.CountryOrRegion
        }
        $Query = [Text.StringBuilder]::new()
        $JoinChar = '?'
        foreach ($Parameter in $QueryArgs.Keys) {
            if ($Query.Length -gt 1) {
                $JoinChar = '&'
            }
            $Value = $QueryArgs[$Parameter] -join ','
            [void]$Query.AppendFormat('{0}{1}={2}', $JoinChar, $Parameter, [HttpUtility]::UrlEncode($Value))
        }
        try {
            $this.MapsQueryCount++
            $CleanUri = ('{0}{1}' -f $this.MapsClient.BaseAddress, $Query.ToString())
            $CleanUri = $CleanUri -replace [Regex]::Escape($this.MapsKey), '<APIKEY REDACTED>'
            Write-Debug $CleanUri
            $responseString = $this.MapsClient.GetStringAsync($Query.ToString()).Result
            $Response = ''
            if (![string]::IsNullOrEmpty($responseString)) {
                $Response = $responseString | ConvertFrom-Json
            }
            if ([string]::IsNullOrEmpty($Response)) {
                throw "$CleanUri Produced no results!"
                return
            }
        }
        catch {
            $Address.Warning.Add([WarningType]::MapsValidation, "Maps API failure: $($_.Exception.Message)")
            return
        }

        $AzureMapsAddress = if ( $Response.summary.totalResults -gt 0 ) {
            $MapsAddress = @($Response.results | Sort-Object -Property score -Descending).Where({ $_.type -in @('Point Address', 'Address Range') }, 'First', 1)[0]
            if ($null -eq $MapsAddress) {
                $Address.Warning.Add([WarningType]::MapsValidation, 'No Addresses Found')
                return
            }
            $PostalOrZipCode = switch ($MapsAddress.address.countryCode) {
                { $_ -in @('CA', 'IE', 'GB', 'PT') } {
                    if ([string]::IsNullOrEmpty($Address.address.extendedPostalCode)) {
                        $MapsAddress.address.postalCode
                    }
                    else {
                        $MapsAddress.address.extendedPostalCode
                    }
                }
                default {
                    $MapsAddress.address.postalCode
                }
            }
            [PSCustomObject]@{
                HouseNumber        = $MapsAddress.address.streetNumber
                StreetName         = ($MapsAddress.address.streetName -split ',')[0]
                City               = ($MapsAddress.address.municipality -split ',')[0]
                AlternateCityNames = @(($MapsAddress.address.localName -split ',')[0] , ($MapsAddress.address.municipalitySubdivision -split ',')[0]).Where({ ![string]::IsNullOrEmpty($_) })
                StateOrProvince    = $MapsAddress.address.countrySubdivision
                PostalCode         = $PostalOrZipCode
                Country            = $MapsAddress.address.countryCode
                Latitude           = $MapsAddress.position.lat
                Longitude          = $MapsAddress.position.lon
            }
        }
        if (!$AzureMapsAddress) {
            Write-Debug ($Response | ConvertTo-Json -Compress)
        }
        $MapResultString = $($AzureMapsAddress | ConvertTo-Json -Compress)
        $ResultFound = ![string]::IsNullOrEmpty($MapResultString)
        if (!$ResultFound) {
            $Address.Warning.Add([WarningType]::MapsValidation, 'Address Not Found')
        }
        $Warned = $false
        # write warnings for changes from input
        $AzureAddress = '{0} {1}' -f $AzureMapsAddress.HouseNumber, $AzureMapsAddress.StreetName
        if ($ResultFound -and !($this.TestIsAddressMatch($AzureAddress, $Address.Address))) {
            # need to be better with fuzzy match here
            $Address.Warning.Add([WarningType]::MapsValidation, "Provided Address: '$($Address.Address)' does not match Azure Maps Address: '$($AzureAddress)'!")
            $Warned = $true
        }
        if ($ResultFound -and $Address.City -ne $AzureMapsAddress.City -and $Address.City -notin $AzureMapsAddress.AlternateCityNames) {
            # need to be better with fuzzy match here
            $Address.Warning.Add([WarningType]::MapsValidation, "Provided City: '$($Address.City)' does not match Azure Maps City: '$($AzureMapsAddress.City)'!")
            $Warned = $true
        }
        if ($ResultFound -and $Address.StateOrProvince -ne $AzureMapsAddress.StateOrProvince) {
            $Address.Warning.Add([WarningType]::MapsValidation, "Provided StateOrProvince: '$($Address.StateOrProvince)' does not match Azure Maps StateOrProvince: '$($AzureMapsAddress.StateOrProvince)'!")
            $Warned = $true
        }
        if ($ResultFound -and $Address.PostalCode -ne $AzureMapsAddress.PostalCode) {
            $Address.Warning.Add([WarningType]::MapsValidation, "Provided PostalCode: '$($Address.PostalCode)' does not match Azure Maps PostalCode: '$($AzureMapsAddress.PostalCode)'!")
            $Warned = $true
        }
        if ($ResultFound -and $Address.CountryOrRegion -ne $AzureMapsAddress.Country) {
            $Address.Warning.Add([WarningType]::MapsValidation, "Provided Country: '$($Address.CountryOrRegion)' does not match Azure Maps Country: '$($AzureMapsAddress.Country)'!")
            $Warned = $true
        }
        if ($ResultFound -and ![string]::IsNullOrEmpty($Address.Latitude) -and ![string]::IsNullOrEmpty($Address.Longitude) -and $Address.Latitude -ne 0 -and $Address.Longitude -ne 0) {
            if (!$this.CompareDoubleFuzzy($Address.Latitude, $AzureMapsAddress.Latitude)) {
                $Address.Warning.Add([WarningType]::MapsValidation, "Provided Latitude: '$($Address.Latitude)' does not match Azure Maps Latitude: '$($AzureMapsAddress.Latitude)'!")
                $Warned = $true
            }
            if (!$this.CompareDoubleFuzzy($Address.Longitude, $AzureMapsAddress.Longitude)) {
                $Address.Warning.Add([WarningType]::MapsValidation, "Provided Longitude: '$($Address.Longitude)' does not match Azure Maps Longitude: '$($AzureMapsAddress.Longitude)'!")
                $Warned = $true
            }
        }
        if ($ResultFound -and [string]::IsNullOrEmpty($Address.Latitude) -or [string]::IsNullOrEmpty($Address.Longitude) -or ($Address.Latitude -eq 0 -and $Address.Longitude -eq 0)) {
            $Address.Latitude = $AzureMapsAddress.Latitude
            $Address.Longitude = $AzureMapsAddress.Longitude
        }
        if ($ResultFound -and $Warned) {
            $Address.Warning.Add([WarningType]::MapsValidationDetail, "AzureMapsAddress: $($AzureMapsAddress | ConvertTo-Json -Compress)")
        }
    }

    [bool] CompareDoubleFuzzy([double] $ReferenceNum, [double] $DifferenceNum) {
        $Same = [Math]::Round($ReferenceNum, $this._geocodeDecimalPlaces) -eq [Math]::Round($DifferenceNum, $this._geocodeDecimalPlaces)
        if ($Same) {
            return $true
        }
        $Delta = [Math]::Abs($ReferenceNum - $DifferenceNum)
        $FmtString = [string]::new('0', $this._geocodeDecimalPlaces + 1)
        $IsFuzzyMatch = [Math]::Round($Delta, $this._geocodeDecimalPlaces) -eq 0 -or $ReferenceNum.ToString("0.$FmtString").Substring(0,$this._geocodeDecimalPlaces + 2) -eq $DifferenceNum.ToString("0.$FmtString").Substring(0,$this._geocodeDecimalPlaces + 2)
        return $IsFuzzyMatch
    }
    [string] _getAddressInMapsQueryForm([E911Address] $Address) {
        $sb = [StringBuilder]::new()
        $sb.Append((@($Address.Address, $Address.City, $Address.StateOrProvince, $Address.PostalCode) -join ' '))
        do {
            # remove all double spaces until there are no more
            $len = $sb.Length
            $null = $sb.Replace('  ', ' ')
        } while ($sb.Length -lt $len)
        return $sb.ToString().Trim()
    }
    [void] ResetQueryCounter() {
        $this._mapsQueryCount = 0
    }

    hidden [string] $_azureMapsApiKey
    hidden [HttpClient] $_mapsClient
    hidden [int] $_geocodeDecimalPlaces = 3
    hidden [int] $_mapsQueryCount = 0
    static AddressValidator() {
        [PSClassProperty]::UpdateType(([AddressValidator]), [PSClassProperty[]]@(
                @{
                    Name   = 'MapsClient'
                    Getter = {
                        if ($null -eq $this._mapsClient) {
                            $this._mapsClient = [HttpClient]::new()
                            $this._mapsClient.BaseAddress = 'https://atlas.microsoft.com/search/address/json'
                        }
                        return $this._mapsClient
                    } 
                },
                @{
                    Name   = 'MapsKey'
                    Getter = {
                        if ([string]::IsNullOrEmpty($this._azureMapsApiKey) -and ![string]::IsNullOrEmpty($env:AZUREMAPS_API_KEY) -and $env:AZUREMAPS_API_KEY -ne $this._azureMapsApiKey) {
                            $this._azureMapsApiKey = $env:AZUREMAPS_API_KEY
                        }
                        return $this._azureMapsApiKey
                    } 
                },
                @{
                    Name   = 'AbbreviationLookup'
                    Getter = { 
                        return $this.s_replacementdictionary.Value
                    }
                },
                @{
                    Name   = 'MapsQueryCount'
                    Setter = {
                        param([int]$value)
                        if (($value - $this._mapsQueryCount) -eq 1) {
                            $this._mapsQueryCount = $value
                        }
                    }
                    Getter = { 
                        return $this._mapsQueryCount
                    }
                }
            ))
    }
}
