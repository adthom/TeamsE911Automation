if ([string]::IsNullOrEmpty($env:AZUREMAPS_API_KEY)) {
    Write-Warning "Could not find AZUREMAPS_API_KEY, be sure to set env var before executing"
}