# #Requires -Modules ..\TeamsE911Automation
using module ..\TeamsE911Automation.psd1
using namespace System.Collections.Generic
using namespace System.Collections
using namespace System.Text

[CmdletBinding(SupportsShouldProcess)]
param ()

function Get-CleanParamString {
    param (
        [hashtable]
        $Params
    )
    $replacePattern = '[''"\s|&<>@#\(\);,`]'
    $psb = [StringBuilder]::new()
    foreach ($key in $Params.Keys) {
        if ($psb.Length -gt 0) { $null = $psb.Append(' ') }
        $null = $psb.Append('-')
        $null = $psb.Append($key)
        $value = $Params[$key]
        if ($value -is [bool]) {
            $null = $psb.Append(':$')
            $null = $psb.Append($value.ToString().ToLower())
            continue
        }
        $null = $psb.Append(' ')
        if ($value -is [ICollection]) {
            for ($i = 0; $i -lt $value.Count; $i++) {
                if ($i -gt 0) { $null = $psb.Append(',') }
                if ($value[$i] -is [string]) {
                    $valstr = $value[$i].ToString()
                    $quote = $valstr -match $replacePattern
                    if ($quote) { $null = $psb.Append('''') }
                    if ($quote) { $valstr = $valstr.Replace('''', '''''') }
                    $null = $psb.Append($valstr)
                    if ($quote) { $null = $psb.Append('''') }
                    continue
                }
                if ($value[$i] -is [bool]) {
                    $null = $psb.Append('$')
                    $null = $psb.Append($value[$i].ToString().ToLower())
                    continue
                }
                $null = $psb.Append($value[$i].ToString())
            }
            continue
        }
        $valstr = $value.ToString()
        $quote = $valstr -match $replacePattern
        if ($quote) { $null = $psb.Append('''') }
        if ($quote) { $valstr = $valstr.Replace('''', '''''') }
        $null = $psb.Append($valstr)
        if ($quote) { $null = $psb.Append('''') }
    }
}

[Dictionary[string, List[LisLocation]]]$LocationLookup = @{}
$onlineObjects = [LisObjectHelper]::GetAll($true)
$Status = @{}
$Status['Address'] = @{}
$Status['Location'] = @{}
Write-Host 'Finding unused addresses...'
$Status['Address']['InUse'], $Status['Address']['NotInUse'] = $onlineObjects[[LisCivicAddress]].Where({ $_.IsInUse() }, 'Split')
Write-Host "Found $($Status['Address']['NotInUse'].Count) unused addresses"

Write-Host 'Finding unused locations...'
$Status['Location']['InUse'], $Status['Location']['NotInUse'] = $onlineObjects[[LisLocation]].Where({ $_.IsInUse() }, 'Split')
Write-Host "Found $($Status['Location']['NotInUse'].Count) unused locations"

$lisLocations = [LisLocation]::GetAll()
$locationSet = [LisLocationPrioritySet]$lisLocations

Write-Host 'Finding duplicated locations...'
foreach ($location in $Status['Location']['InUse'].Where({!$locationSet.Contains($_)})) {
    if (!$LocationLookup.ContainsKey($location.GetHash())) {
        $LocationLookup[$location.GetHash()] = @()
    }
    $LocationLookup[$location.GetHash()].Add($location)
}
$DuplicatedHashes = $LocationLookup.Keys
$LocationsToRemove = [List[LisLocation]]@($Status['Location']['NotInUse'])
$AddressesToRemove = [List[LisCivicAddress]]@($Status['Address']['NotInUse'])
$TotalUneededLocations = $lisLocations.Count - $locationSet.Count
Write-Host "Found $($DuplicatedHashes.Count) duplicated locations ($TotalUneededLocations locations to remove)"
foreach ($locationHash in $DuplicatedHashes) {
    $Locations = $LocationLookup[$locationHash]
    $TargetLocation = $Locations.Where({$locationSet.Contains($_)})[0]
    # $TargetLocation = $Locations | Sort-Object { $_.GetAssociatedNetworkObjects().Count } -Descending | Select-Object -First 1
    $LocationsToMigrate = $Locations | Where-Object { $_.Id -ne $TargetLocation.Id }
    foreach ($location in $LocationsToMigrate) {
        Write-Host "Migrating $($location.LocationId) to $($TargetLocation.LocationId)"
        $networkObjects = $location.GetAssociatedNetworkObjects()
        foreach ($networkObject in $networkObjects) {
            $params = @{
                LocationId = $TargetLocation.LocationId
            }
            $idParams = $networkObject.IdentifierParams()
            foreach ($p in $idParams) {
                $params[$p] = $idParams[$p]
            }
            $CommandName = 'Set-CsOnlineLis{0}' -f $networkObject.Type
            $Command = Get-Command -Name $CommandName
            Write-Host "Migrating $($networkObject.Type) $($networkObject.Identifier()) to $($TargetLocation.LocationId)"
            if ($PSCmdlet.ShouldProcess("$($networkObject.Type) $($networkObject.Identifier()) to $($TargetLocation.LocationId)", $CommandName)) {
                #{ & $Command @params }.Invoke()
                Write-Warning "This didnt prompt"
            }
            else {
                $ParamString = Get-CleanParamString -Params $params
                @($CommandName, $ParamString) -join ' ' | Write-Output   
            }
        }
        $address = $location.GetCivicAddress()
        if ($address.DefaultLocationId -ne $location.LocationId) {
            Write-Host "Removing location $($location.LocationId)"
            if ($PSCmdlet.ShouldProcess($location.LocationId, 'Remove-CsOnlineLisLocation')) {
                # Remove-CsOnlineLisLocation -LocationId $location.LocationId
                Write-Warning "This didnt prompt"
            }
            else {
                "Remove-CsOnlineLisLocation -LocationId $($location.LocationId)" | Write-Output
            }
        }
        else {
            Write-Host "$($location.LocationId) is a default location, will check if it can be removed later"
            $LocationsToRemove.Add($location)
        }
    }
}
foreach ($location in $LocationsToRemove) {
    $address = $location.GetCivicAddress()
    if ($address.DefaultLocationId -ne $location.LocationId) {
        Write-Host "Removing location $($location.LocationId)"
        if ($PSCmdlet.ShouldProcess($location.LocationId, 'Remove-CsOnlineLisLocation')) {
            # Remove-CsOnlineLisLocation -LocationId $location.LocationId
            Write-Warning "This didnt prompt"
        }
        else {
            "Remove-CsOnlineLisLocation -LocationId $($location.LocationId)" | Write-Output
        }
    }
    elseif (!$address.IsInUse($false) -or !$address.IsInUse($true)) {
        $AddressesToRemove.Add($address)
    }
    else {
        Write-Host "Location $($location.LocationId) is the default location for address $($address.CivicAddressId) and cannot be removed because the address is in use."
    }
}
foreach ($address in $AddressesToRemove) {
    Write-Host "Removing address $($address.CivicAddressId)"
    if ($PSCmdlet.ShouldProcess($address.CivicAddressId, 'Remove-CsOnlineLisCivicAddress')) {
        # Remove-CsOnlineLisCivicAddress -CivicAddressId $address.CivicAddressId
        Write-Warning "This didnt prompt"
    }
    else {
        "Remove-CsOnlineLisCivicAddress -CivicAddressId $($address.CivicAddressId)" | Write-Output
    }
}