param (
    [bool]
    $Verbose = $false,

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

$ConfigApiCmdlets = [Microsoft.Teams.ConfigApi.Cmdlets.SessionStateStore]::TryConfigApiSessionInfo.SessionConfiguration.RemotingCmdletsFlightedForAutoRest
$ExistingConfiguration = [Collections.Generic.List[string]]::new()
$ExistingConfiguration.AddRange($ConfigApiCmdlets) | Out-Null
$CmdletsToCheck = Get-Command -Verb @('Get', 'Set', 'Remove') -Noun CsOnlineLis* | Select-Object -ExpandProperty Name
$changedFlighting = $false
Write-Information "$([string]::new('*', ($host.UI.RawUI.BufferSize.Width - 5)))"
Write-Information ""
Write-Information "Here is the current cmdlet endpoint configuration:"
Write-Information ""
Write-Information "$([string]::new('*', ($host.UI.RawUI.BufferSize.Width - 5)))"
Write-Information ""
foreach ($cmdlet in $CmdletsToCheck) {
    if ($cmdlet -in $ConfigApiCmdlets) {
        Write-Information "REST:   $cmdlet"
        if ($Endpoint -eq "Legacy") {
            $ConfigApiCmdlets.Remove($cmdlet) | Out-Null
            $changedFlighting = $true
        }
    }
    else {
        Write-Information "Legacy: $cmdlet"
        if ($Endpoint -eq "REST") {
            $ConfigApiCmdlets.Add($cmdlet) | Out-Null
            $changedFlighting = $true
        }
    }
}
if ($changedFlighting) {
    Write-Information ""
    Write-Information "$([string]::new('*', ($host.UI.RawUI.BufferSize.Width - 5)))"
    Write-Information ""
    Write-Information "Flighting configuration has changed!"
    Write-Information "Here is the new endpoint configuration:"
    Write-Information ""
    Write-Information "$([string]::new('*', ($host.UI.RawUI.BufferSize.Width - 5)))"
    Write-Information ""
    foreach ($cmdlet in $CmdletsToCheck) {
        if ($cmdlet -in $ConfigApiCmdlets) {
            Write-Information "REST:   $cmdlet"
        }
        else {
            Write-Information "Legacy: $cmdlet"
        }
    }
}

Write-Information ""

function Remove-CsE911Configuration {
    [CmdletBinding()]
    param ()
    (Get-CsOnlineLisSubnet) | Where-Object { $_.Subnet } | ForEach-Object { Remove-CsOnlineLisSubnet -Subnet $_.Subnet | Out-Null }
    (Get-CsOnlineLisSwitch) | Where-Object { $_.ChassisID } | ForEach-Object { Remove-CsOnlineLisSwitch -ChassisID $_.ChassisID | Out-Null }
    (Get-CsOnlineLisPort) | Where-Object { $_.ChassisID -and $_.PortID } | ForEach-Object { Remove-CsOnlineLisPort -PortId $_.PortID -ChassisID $_.ChassisID | Out-Null }
    (Get-CsOnlineLisWirelessAccessPoint) | Where-Object { $_.BSSID } | ForEach-Object { Remove-CsOnlineLisWirelessAccessPoint -BSSID $_.BSSID | Out-Null }
    $Addresses = Get-CsOnlineLisCivicAddress -PopulateNumberOfVoiceUsers -PopulateNumberOfTelephoneNumbers
    (Get-CsOnlineLisLocation) | Where-Object { $_.LocationId -notin $Addresses.DefaultLocationId -and 
        $null -ne (Get-CsOnlineLisCivicAddress -CivicAddressId $_.CivicAddressId -ErrorAction SilentlyContinue)} | ForEach-Object {
        Remove-CsOnlineLisLocation -LocationId $_.LocationId | Out-Null
    }
    $Addresses | Where-Object { $_.NumberOfVoiceUsers -le 0 -and $_.NumberOfTelephoneNumbers -le 0 } | ForEach-Object {
        Remove-CsOnlineLisCivicAddress -CivicAddressId $_.CivicAddressId | Out-Null
    }
}

try {
    $mainsw = [Diagnostics.Stopwatch]::StartNew()
    # push current location onto stack so we can change context back at finish
    Push-Location
    Set-Location -Path $PSScriptRoot

    # remove loaded module to allow using/import statement to function
    Remove-Module -Name TeamsE911Automation -ErrorAction SilentlyContinue

    # import secrets
    . .\test_secrets.ps1

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
        Write-Information "$([string]::new('*', ($host.UI.RawUI.BufferSize.Width - 5)))"
        Write-Information ""
        Write-Information "Running Test $($Test.Name)..."
        Write-Information ""
        Write-Information "$([string]::new('*', ($host.UI.RawUI.BufferSize.Width - 5)))"
        Write-Information ""
        $sw.Restart()
        try {
            & $Test.FullName -Verbose:$Verbose
            Write-Information ""
            Write-Information "$([string]::new('*', ($host.UI.RawUI.BufferSize.Width - 5)))"
            Write-Information ""
            Write-Information "$($Test.Name) Done! [TotalSeconds: $($sw.Elapsed.TotalSeconds.ToString('F3'))]"
            Write-Information ""
            Write-Information "$([string]::new('*', ($host.UI.RawUI.BufferSize.Width - 5)))"
            Write-Information ""
        }
        catch {
            Write-Information ""
            Write-Information "$([string]::new('*', ($host.UI.RawUI.BufferSize.Width - 5)))"
            Write-Information ""
            Write-Warning "Loop Catch for $Test"
            Write-Warning $_
            Write-Information ""
            Write-Information "$([string]::new('*', ($host.UI.RawUI.BufferSize.Width - 5)))"
            Write-Information ""
            Write-Information "$($Test.Name) Done! [TotalSeconds: $($sw.Elapsed.TotalSeconds.ToString('F3'))]"
            Write-Information ""
            Write-Information "$([string]::new('*', ($host.UI.RawUI.BufferSize.Width - 5)))"
            Write-Information ""
        }
    }
}
catch {
    Write-Information ""
    Write-Information "$([string]::new('*', ($host.UI.RawUI.BufferSize.Width - 5)))"
    Write-Information ""
    Write-Warning "Main Catch"
    Write-Error $_
    Write-Information ""
    Write-Information "$([string]::new('*', ($host.UI.RawUI.BufferSize.Width - 5)))"
}
finally {
    $sw.Stop()
    if ($changedFlighting) {
        Write-Information ""
        Write-Information "$([string]::new('*', ($host.UI.RawUI.BufferSize.Width - 5)))"
        Write-Information ""
        Write-Information "Flighting configuration has changed, resetting back to original..."
        $ConfigApiCmdlets = [Microsoft.Teams.ConfigApi.Cmdlets.SessionStateStore]::TryConfigApiSessionInfo.SessionConfiguration.RemotingCmdletsFlightedForAutoRest
        foreach ($prev in $ExistingConfiguration) {
            if ($prev -notin $ConfigApiCmdlets) {
                $ConfigApiCmdlets.Add($prev) | Out-Null
            }
        }
        $Added = [Collections.Generic.List[string]]::new()
        foreach ($curr in $ConfigApiCmdlets) {
            if ($curr -notin $ExistingConfiguration) {
                $Added.Add($curr) | Out-Null
            }
        }
        foreach ($curr in $Added) {
            if ($curr -notin $ExistingConfiguration) {
                $ConfigApiCmdlets.Remove($curr) | Out-Null
            }
        }
        Write-Information ""
        Write-Information "$([string]::new('*', ($host.UI.RawUI.BufferSize.Width - 5)))"
    }
    Write-Information ""
    Write-Information "$([string]::new('*', ($host.UI.RawUI.BufferSize.Width - 5)))"
    Write-Information ""
    Write-Information "All tests Done! [TotalSeconds: $($mainsw.Elapsed.TotalSeconds.ToString('F3'))]"
    Write-Information ""
    Write-Information "$([string]::new('*', ($host.UI.RawUI.BufferSize.Width - 5)))"

    $mainsw.Stop()
    Pop-Location
}