param (
    [switch]
    $Verbose,

    [ValidateSet("Default", "REST", "Legacy", IgnoreCase = $true)]
    [string]
    $Endpoint = "Default",

    [string]
    $OverrideTest = ""
)

try {
    [Microsoft.TeamsCmdlets.Powershell.Connect.TeamsPowerShellSession]::ClientAuthenticated()
}
catch {
    throw "Run Connect-MicrosoftTeams prior to executing this script!"
}

function Remove-CsE911Configuration {
    [CmdletBinding()]
    param ()
    $Subnets = @(Get-CsOnlineLisSubnet).Where({ $_.Subnet })
    $i = 0
    foreach ($Subnet in $Subnets) {
        Write-Verbose "Removing Subnet:$($Subnet.Subnet)"
        $null = Remove-CsOnlineLisSubnet -Subnet $Subnet.Subnet
        $i++
    }
    Write-Information "Removed $i subnets"

    $Switches = @(Get-CsOnlineLisSwitch).Where({ $_.ChassisId })
    $i = 0
    foreach ($Switch in $Switches) {
        Write-Verbose "Removing Switch:$($Switch.ChassisId)"
        $null = Remove-CsOnlineLisSwitch -ChassisId $Switch.ChassisId
        $i++
    }
    Write-Information "Removed $i switches"

    $Ports = @(Get-CsOnlineLisPort).Where({ $_.ChassisId -and $_.PortId })
    $i = 0
    foreach ($Port in $Ports) {
        Write-Verbose "Removing Port:$($Port.ChassisId):$($Port.PortId)"
        $null = Remove-CsOnlineLisPort -PortId $Port.PortId -ChassisId $Port.ChassisId
        $i++
    }
    Write-Information "Removed $i ports"

    $WirelessAccessPoints = @(Get-CsOnlineLisWirelessAccessPoint).Where({ $_.Bssid })
    $i = 0
    foreach ($WAP in $WirelessAccessPoints) { 
        Write-Verbose "Removing WAP:$($WAP.Bssid)"
        $null = Remove-CsOnlineLisWirelessAccessPoint -Bssid $WAP.Bssid
        $i++
    }
    Write-Information "Removed $i wireless access points"

    $Addresses = @(Get-CsOnlineLisCivicAddress -PopulateNumberOfVoiceUsers -PopulateNumberOfTelephoneNumbers)
    $Locations = @(Get-CsOnlineLisLocation)
    $i = 0
    $j = 0
    foreach ($Location in $Locations) {
        $addr = $Addresses.Where({ $_.CivicAddressId -eq $Location.CivicAddressId -and $Location.LocationId -ne $_.DefaultLocationId })
        if ($null -eq $addr -or $addr.Count -eq 0) { continue }
        Write-Verbose "Removing Location:$($Location.LocationId)-$($Location.Location)"
        $null = Remove-CsOnlineLisLocation -LocationId $Location.LocationId
        $i++
    }
    foreach ($Address in $Addresses) {
        if ($Address.NumberOfVoiceUsers -gt 0 -or $Address.NumberOfTelephoneNumbers -gt 0 ) { continue }
        Write-Verbose "Removing Address:$($Address.CivicAddressId)-$($Address.HouseNumber) $($Address.StreetName)"
        $null = Remove-CsOnlineLisCivicAddress -CivicAddressId $Address.CivicAddressId
        $j++
    }
    Write-Information "Removed $i locations"
    Write-Information "Removed $j addresses"
}

function Write-Separator {
    Write-Information ""
    Write-Information "$([string]::new('*', ($host.UI.RawUI.BufferSize.Width - 5)))"
    Write-Information ""
}

function Write-TestStart {
    param (
        $Name
    )
    Write-Separator
    Write-Information "Running Test $Name..."
    Write-Separator
}

function Write-TestEnd {
    param (
        $Name,
        [Diagnostics.Stopwatch]
        $sw
    )
    Write-Separator
    Write-Information "$Name Done! [TotalSeconds: $($sw.Elapsed.TotalSeconds.ToString('F3'))]"
    Write-Separator
}

$ConfigApiCmdlets = [Microsoft.Teams.ConfigApi.Cmdlets.SessionStateStore]::TryConfigApiSessionInfo.SessionConfiguration.RemotingCmdletsFlightedForAutoRest
$ExistingConfiguration = [Collections.Generic.List[string]]::new()
$null = $ExistingConfiguration.AddRange($ConfigApiCmdlets)
$CmdletsToCheck = Get-Command -Verb @('Get', 'Set', 'Remove') -Noun CsOnlineLis* | Select-Object -ExpandProperty Name
$changedFlighting = $false
Write-Separator
Write-Information "Here is the current cmdlet endpoint configuration:"
Write-Separator
foreach ($cmdlet in $CmdletsToCheck) {
    if ($cmdlet -in $ConfigApiCmdlets) {
        Write-Information "REST:   $cmdlet"
        if ($Endpoint -eq "Legacy") {
            $null = $ConfigApiCmdlets.Remove($cmdlet)
            $changedFlighting = $true
        }
    }
    else {
        Write-Information "Legacy: $cmdlet"
        if ($Endpoint -eq "REST") {
            $null = $ConfigApiCmdlets.Add($cmdlet)
            $changedFlighting = $true
        }
    }
}
if ($changedFlighting) {
    Write-Separator
    Write-Information "Flighting configuration has changed!"
    Write-Information "Here is the new endpoint configuration:"
    Write-Separator
    foreach ($cmdlet in $CmdletsToCheck) {
        if ($cmdlet -in $ConfigApiCmdlets) {
            Write-Information "REST:   $cmdlet"
        }
        else {
            Write-Information "Legacy: $cmdlet"
        }
    }
}

try {
    $mainsw = [Diagnostics.Stopwatch]::StartNew()
    # push current location onto stack so we can change context back at finish
    Push-Location
    Set-Location -Path $PSScriptRoot

    # import secrets
    . .\test_secrets.ps1

    # remove loaded module to allow using/import statement to function
    Remove-Module -Name TeamsE911Automation -ErrorAction SilentlyContinue -Verbose:$false

    # run test script(s)
    $Tests = Get-ChildItem -Path . -Recurse -File -Filter '*.ps1' | Where-Object { $_.BaseName -match '^test(\d+)?$' }
    if (![string]::IsNullOrEmpty($OverrideTest)) {
        $Tests = $Tests | Where-Object { $_.BaseName -eq $OverrideTest }
        if ($Tests.Count -eq 0) {
            Write-Warning "No tests found matching the name '$OverrideTest'!"
        }
    }
    $sw = [Diagnostics.Stopwatch]::new()
    foreach ($Test in $Tests) {
        Write-TestStart $Test.Name
        $sw.Restart()
        try {
            & $Test.FullName -Verbose:$Verbose
        }
        catch {
            Write-Separator
            Write-Warning "Loop Catch for $Test"
            Write-Warning $_
        }
        Write-TestEnd $Test.Name $sw
    }
}
catch {
    Write-Separator
    Write-Warning "Main Catch"
    Write-Error $_
    Write-Separator
}
finally {
    $sw.Stop()
    if ($changedFlighting) {
        Write-Separator
        Write-Information "Flighting configuration has changed, resetting back to original..."
        $ConfigApiCmdlets = [Microsoft.Teams.ConfigApi.Cmdlets.SessionStateStore]::TryConfigApiSessionInfo.SessionConfiguration.RemotingCmdletsFlightedForAutoRest
        foreach ($prev in $ExistingConfiguration) {
            if ($prev -notin $ConfigApiCmdlets) {
                $null = $ConfigApiCmdlets.Add($prev)
            }
        }
        $Added = [Collections.Generic.List[string]]::new()
        foreach ($curr in $ConfigApiCmdlets) {
            if ($curr -notin $ExistingConfiguration) {
                $null = $Added.Add($curr)
            }
        }
        foreach ($curr in $Added) {
            if ($curr -notin $ExistingConfiguration) {
                $null = $ConfigApiCmdlets.Remove($curr)
            }
        }
        Write-Separator
    }
    Write-TestEnd 'All tests' $mainsw
    $mainsw.Stop()
    Pop-Location
}