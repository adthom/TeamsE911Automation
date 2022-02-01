function Get-AzureMapsValidAddress {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeLineByPropertyName = $true)]
        [string]
        $Address,

        [Parameter(Position = 1, ValueFromPipeLineByPropertyName = $true)]
        [Alias("CityOrTown", "Town")]
        [string]
        $City,

        [Parameter(Position = 2, ValueFromPipeLineByPropertyName = $true)]
        [Alias("State", "Province")]
        [string]
        $StateOrProvince,

        [Parameter(Position = 3, ValueFromPipeLineByPropertyName = $true)]
        [Alias("ZipCode")]
        [string]
        $PostalCode,

        [Parameter(Position = 4, ValueFromPipeLineByPropertyName = $true)]
        [Alias("Country", "Region")]
        [string]
        $CountryOrRegion
    )
    begin {
        # we can also do AAD auth to this as well, (maybe MSI? Unsure how we should set, just using env var for now)
        $ApiKey = $env:AZUREMAPS_API_KEY

        $baseuri = 'https://atlas.microsoft.com/search/address/json'
        $maxResults = 10
    }
    process {
        $AddressParts = @()
        if (![string]::IsNullOrEmpty($Address)) {
            $Address = $Address.Trim()
            $AddressParts += $Address
        }
        if (![string]::IsNullOrEmpty($City)) {
            $City = $City.Trim()
            $AddressParts += $City
        }
        if (![string]::IsNullOrEmpty($StateOrProvince)) {
            $StateOrProvince = $StateOrProvince.Trim()
            $AddressParts += $StateOrProvince
        }
        if (![string]::IsNullOrEmpty($PostalCode)) {
            $PostalCode = $PostalCode.Trim()
            $AddressParts += $PostalCode
        }
        if (![string]::IsNullOrEmpty($CountryOrRegion)) {
            $CountryOrRegion = $CountryOrRegion.Trim()
        }

        $addressQuery = $AddressParts -join ' '

        $QueryArgs = @{
            'subscription-key' = $ApiKey
            'api-version'      = '1.0'
            query              = $addressQuery
            limit              = $maxResults
        }
        if ($CountryOrRegion) {
            $QueryArgs['countrySet'] = $CountryOrRegion
        }

        $Query = ConvertTo-QueryString -QueryHash $QueryArgs

        $uri = '{0}?{1}' -f $baseuri, $Query

        # check if azureHTTPClient exists, if not, initialize it
        if ($null -eq $script:azureHTTPClient) {
            Write-Verbose "azureHTTPClient is null, initializing..."
            $script:azureHTTPClient = [System.Net.Http.HttpClient]::new()
        }
        try {
            Write-Verbose ($uri -replace [Regex]::Escape($ApiKey), "<APIKEY REDACTED>")
            $response = $azureHTTPClient.GetStringAsync($uri).Result | ConvertFrom-Json
        }
        catch {
            return
        }

        $results = if ( $Response.summary.totalResults -gt 0 ) {
            ConvertFrom-AzureMapsResult -Results $Response.results
        }
        if (!$results) {
            Write-Verbose ($Response | ConvertTo-Json -Compress)
        }
        return $Results
    }
}

