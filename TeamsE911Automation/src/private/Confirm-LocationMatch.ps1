function Confirm-LocationMatch {
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
            "Elin",
            "Location"
        )
    }

    process {
        # Confirm CivicAddress matches
        $DoesMatch = $DoesMatch -and (Confirm-CivicAddressMatch -New $New -Cached $Cached -NoDescription)

        for ($i = 0; $i -lt $MatchProperties.Count; $i++) {
            $Property = $MatchProperties[$i]
            $CachedValue = $Cached.$Property
            $NewValue = $New.$Property
            if (![string]::IsNullOrEmpty($CachedValue)) {
                $CachedValue = $CachedValue.ToLower().Trim()
            }
            else {
                $CachedValue = $null
            }
            if (![string]::IsNullOrEmpty($NewValue)) {
                $NewValue = $NewValue.ToLower().Trim()
            }
            else {
                $NewValue = $null
            }
            $PropertyDoesMatch = $CachedValue -eq $NewValue
            if (!$PropertyDoesMatch) {
                Write-Warning "Cached ${Property}: $CachedValue does not equal new ${Property}: $NewValue"
            }
            $DoesMatch = $DoesMatch -and $PropertyDoesMatch
        }
        if (!$DoesMatch) {
            Write-Warning "New Location must be created!"
        }
    }

    end {
        return $DoesMatch
    }
}
