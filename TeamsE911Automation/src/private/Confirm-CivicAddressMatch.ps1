function Confirm-CivicAddressMatch {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        # Parameter help description
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $false)]
        [PSObject]
        $Cached,

        # Parameter help description
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSObject]
        $New
    )

    begin {
        $DoesMatch = $true

        $MatchProperties = @(
            "City",
            "CompanyName",
            "CompanyTaxId",
            "CountryOrRegion",
            "Description",
            "PostalCode",
            "StateOrProvince",
            "Address"
        )
    }

    process {
        # Convert CivicAddress to Address
        $Address = ConvertTo-CsE911AddressString -CivicAddress $Cached
        for ($i = 0; $i -lt $MatchProperties.Count; $i++) {
            $Property = $MatchProperties[$i]
            $CachedValue = if ($Property -eq 'Address') {
                $Address
            }
            else {
                $Cached.$Property
            }
            $NewValue = $New.$Property
            if (![string]::IsNullOrEmpty($CachedValue)) {
                $CachedValue = $CachedValue.ToLower().Trim()
            }
            if (![string]::IsNullOrWhiteSpace($NewValue)) {
                $NewValue = $NewValue.ToLower().Trim()
            }
            else {
                # if new value is blank, assume value from cached entry is good
                $NewValue = $CachedValue
            }
            $PropertyDoesMatch = $CachedValue -eq $NewValue
            if ($Property -eq "CountryOrRegion" -and $NewValue.Length -gt 2 -and $CachedValue.Length -eq 2) {
                # allow ISO country code in cached value to trump non-ISO country string
                $PropertyDoesMatch = $true
            }
            if ($Property -eq "City" -and ($CachedValue.Contains('-') -or $CachedValue.Contains(' ')) -and ($CachedValue.StartsWith($NewValue) -or $CachedValue.EndsWith($NewValue))) {
                # handle fuzzy match for municipality changes
                $PropertyDoesMatch = $true
            }
            if (!$PropertyDoesMatch) {
                Write-Warning "Cached ${Property}: $CachedValue does not equal new ${Property}: $NewValue"
            }
            $DoesMatch = $DoesMatch -and $PropertyDoesMatch
        }
        if (!$DoesMatch) {
            Write-Warning "New Civic Address must be created!"
        }
    }

    end {
        return $DoesMatch
    }
}
