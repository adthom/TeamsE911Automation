function Get-EGWReport {
    param (
        [Parameter(Mandatory = $true)]
        $EGWFqdn,

        [Parameter(Mandatory = $true)]
        [ValidateSet("locations", "wlan", "subnets", "switches")]
        [string]
        $Report
    )
    $Url = 'https://{0}/batch_process/{1}/reports/detailed_{1}_report.csv' -f $EGWFqdn, $Report
    try {
        $Result = Invoke-RestMethod -Method Get -Uri $Url -ErrorAction Stop
        return $Result | ConvertFrom-Csv
    }
    catch {
        return $null
    }
}

function Get-EGWERLs {
    param (
        $EGWFqdn
    )
    $ERLReport = Get-EGWReport -EGWFqdn $EGWFqdn -Report locations

    foreach ($Entry in $ERLReport) {
        if ([string]::IsNullOrEmpty($Entry.ERL_ID)) { continue }
        $Address = "$($Entry.HNO)$($Entry.HNS) "
        if (![string]::IsNullOrEmpty($Entry.PRD)) {
            $Address += "$($Entry.PRD) "
        }
        if (![string]::IsNullOrEmpty($Entry.PRD)) {
            $Address += "$($Entry.PRD) "
        }
        if (![string]::IsNullOrEmpty($Entry.STS)) {
            $Address += "$($Entry.STS) "
        }
        if (![string]::IsNullOrEmpty($Entry.POD)) {
            $Address += "$($Entry.POD) "
        }
        if (![string]::IsNullOrEmpty($Entry.POD)) {
            $Address += "$($Entry.RD) "
        }
        $Address = $Address.Trim()
        [PSCustomObject]@{
            ID              = $Entry.ERL_ID
            CompanyName     = $Entry.NAM
            Description     = $Entry.LOC
            Location        = $Entry.LOC
            City            = $Entry.A3
            StateOrProvince = $Entry.A1
            CountryOrRegion = $Entry.COUNTRY
            PostalCode      = $Entry.PC
            Address         = $Address
        }
    }
}

function Get-EGWWirelessAccessPoints {
    param (
        $EGWFqdn
    )
    $WLANReport = Get-EGWReport -EGWFqdn $EGWFqdn -Report wlan

    foreach ($Entry in $WLANReport) {
        if ([string]::IsNullOrEmpty($Entry.AP_BSSID)) { continue }
        if ([string]::IsNullOrEmpty($Entry.ERL_ID)) { continue }
        $BSSID = $Entry.AP_BSSID.ToUpper() -replace '[^A-F0-9\*]', ''
        $BSSIDParts = $BSSID -split '(\w{2})' | Where-Object { ![string]::IsNullOrEmpty($_) }
        if ($BSSIDParts.Count -ne 6) {
            continue
        }
        $BSSID = $BSSIDParts -join '-'
        $BSSID = $BSSID -replace '(-[A-F0-9])[A-F0-9]$', '$1*'
        [PSCustomObject]@{
            ERLID                   = $Entry.ERL_ID
            NetworkObjectType       = 'WirelessAccessPoint'
            NetworkDescription      = $Entry.AP_NAME
            NetworkObjectIdentifier = $BSSID
        }
    }
}

function Get-EGWSubnets {
    param (
        $EGWFqdn
    )
    $SubnetReport = Get-EGWReport -EGWFqdn $EGWFqdn -Report subnets

    foreach ($Entry in $SubnetReport) {
        if ([string]::IsNullOrEmpty($Entry.SUBNET)) { continue }
        if ([string]::IsNullOrEmpty($Entry.ERL_ID)) { continue }
        $Subnet = ($Entry.SUBNET -split '/')[0]
        [PSCustomObject]@{
            ERLID                   = $Entry.ERL_ID
            NetworkObjectType       = 'Subnet'
            NetworkDescription      = ''
            NetworkObjectIdentifier = $Subnet
        }
    }
}

function Get-EGWSwitchesAndPorts {
    param (
        $EGWFqdn
    )
    $SubnetReport = Get-EGWReport -EGWFqdn $EGWFqdn -Report switches

    $SwitchIPs = [Collections.Generic.List[string]]::new()
    foreach ($Entry in $SubnetReport) {
        if ([string]::IsNullOrEmpty($Entry.SWITCH_IP)) { continue }
        if ([string]::IsNullOrEmpty($Entry.ERL_ID)) { continue }

        $Type = if ([string]::IsNullOrEmpty($Entry.PORT_NAME)) { 'Switch' } else { 'Port' }
        $Identifier = $Entry.SWITCH_IP
        if (!$SwitchIPs.Contains($Identifier)) {
            Write-Warning "Need to find ChassisId for Switch with IP of $($Identifier) and update all found entries!"
            [void]$SwitchIPs.Add($Identifier)
        }
        if ($Type -eq 'PORT') {
            $Identifier = $Identifier + ";$($Entry.PORT_NAME)"
        }
        [PSCustomObject]@{
            ERLID                   = $Entry.ERL_ID
            NetworkObjectType       = $Type
            NetworkDescription      = $Entry.Description
            NetworkObjectIdentifier = $Identifier
        }
    }
}

function Get-EGWNetworkObjects {
    param (
        $EGWFqdn
    )

    Get-EGWWirelessAccessPoints @PSBoundParameters
    Get-EGWSubnets @PSBoundParameters
    Get-EGWSwitchesAndPorts @PSBoundParameters
}

function Get-ConfigFromEGW {
    param (
        $EGWFqdn
    )
    $ERLs = Get-EGWERLs @PSBoundParameters

    $ERLHash = @{}
    foreach ($ERL in $ERLs) {
        if ($ERLHash.ContainsKey($ERL.ID)) { continue }
        $ERLHash[$ERL.ID] = $ERL
    }
    $NetworkObjects = Get-EGWNetworkObjects @PSBoundParameters
    foreach ($Entry in $NetworkObjects) {
        $ERL = $ERLHash[$Entry.ERLID]
        [PSCustomObject]@{
            CompanyName             = $ERL.CompanyName
            Description             = $ERL.Description
            Location                = $ERL.Location
            City                    = $ERL.City
            StateOrProvince         = $ERL.StateOrProvince
            CountryOrRegion         = $ERL.CountryOrRegion
            PostalCode              = $ERL.PostalCode
            Address                 = $ERL.Address
            NetworkObjectType       = $Entry.NetworkObjectType
            NetworkDescription      = if ( [string]::IsNullOrEmpty($Entry.NetworkDescription) ) { "$($Entry.NetworkObjectType) for $($ERL.Location)" } else { $Entry.NetworkDescription }
            NetworkObjectIdentifier = $Entry.NetworkObjectIdentifier
        }
    }
}
