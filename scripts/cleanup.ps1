# using module ..\TeamsE911Automation.psd1
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

$Module = Get-Module -Name TeamsE911Automation
if ($null -eq $Module) {
    $Module = Import-Module ..\TeamsE911Automation.psd1 -PassThru
}

$LisObjectHelperType = & $Module { [LisObjectHelper] }
$LisCivicAddressType = & $Module { [LisCivicAddress] }
$LisLocationType = & $Module { [LisLocation] }
$LisLocationPrioritySetType = & $Module { [LisLocationPrioritySet] }


$onlineObjects = $LisObjectHelperType::GetAll($true)

$lisLocations = $LisLocationType::GetAll()
$locationSet = $lisLocations -as $LisLocationPrioritySetType

Write-Host 'Finding duplicated locations...'
$listType = [Collections.Generic.Dictionary`2]
$concreteType = $listType.MakeGenericType($lisLocationType, $lisLocationType)
$cleanup = [System.Activator]::CreateInstance($concreteType) # [Dictionary[LisLocation, LisLocation]]@{}
foreach ($location in $lisLocations) {
    if (!$locationSet.Contains($location)) {
        $cleanup[$location] = $locationSet.GetDuplicateLocation($location)
        Write-Host "Found duplicate location $($location.LocationId)"
    }
}
$LocationsToRemove = [HashSet[Guid]]@()
$AddressesToRemove = [HashSet[Guid]]@()
if ($cleanup.Count -gt 0) {
    $TotalUneededLocations = $lisLocations.Count - $locationSet.Count
    Write-Host "Found duplicated locations! ($TotalUneededLocations locations to remove)"
}
$dirty = $false
foreach ($location in $cleanup.Keys) {
    $TargetLocation = $cleanup[$location]
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
            { & $Command @params }.Invoke()
        }
        else {
            $ParamString = Get-CleanParamString -Params $params
            @($CommandName, $ParamString) -join ' ' | Write-Output   
        }
        $dirty = $true
    }
    $address = $location.GetCivicAddress()
    if ($address.DefaultLocationId -ne $location.LocationId) {
        Write-Host "Removing location $($location.LocationId)"
        if ($PSCmdlet.ShouldProcess($location.LocationId, 'Remove-CsOnlineLisLocation')) {
            Remove-CsOnlineLisLocation -LocationId $location.LocationId
        }
        else {
            "Remove-CsOnlineLisLocation -LocationId $($location.LocationId)" | Write-Output
        }
        $dirty = $true
    }
    else {
        Write-Host "$($location.LocationId) is a default location, will check if it can be removed later"
        $null = $LocationsToRemove.Add($location.LocationId)
    }
}

if ($dirty) { Write-Host 'Refreshing caches after migrations...' }
$onlineObjects = $LisObjectHelperType::GetAll($dirty)
$Status = @{
    Address  = $null
    Location = $null
}
Write-Host 'Finding unused addresses...'
$Status['Address'] = $onlineObjects[$LisCivicAddressType].Where({ !$_.IsInUse() }).CivicAddressId
Write-Host "Found $($Status['Address'].Count) unused addresses"
foreach ($g in $Status['Address']) {
    $null = $AddressesToRemove.Add($g)
}

Write-Host 'Finding unused locations...'
$Status['Location'] = $onlineObjects[$LisLocationType].Where({ !$_.IsInUse() }).LocationId
Write-Host "Found $($Status['Location'].Count) unused locations"
foreach ($g in $Status['Location']) {
    $null = $LocationsToRemove.Add($g)
}

foreach ($location in $LocationsToRemove) {
    $testLocation = $LisLocationType::GetById($location)
    $address = $testLocation.GetCivicAddress()
    if ($address.DefaultLocationId -ne $testLocation.LocationId) {
        Write-Host "Removing location $($testLocation.LocationId)"
        if ($PSCmdlet.ShouldProcess($testLocation.LocationId, 'Remove-CsOnlineLisLocation')) {
            Remove-CsOnlineLisLocation -LocationId $testLocation.LocationId
        }
        else {
            "Remove-CsOnlineLisLocation -LocationId $($testLocation.LocationId)" | Write-Output
        }
    }
    elseif (!$address.IsInUse()) {
        $null = $AddressesToRemove.Add($address.CivicAddressId)
    }
    else {
        Write-Host "Location $($testLocation.LocationId) is the default location for address $($address.CivicAddressId) and cannot be removed because the address is in use."
    }
}
foreach ($address in $AddressesToRemove) {
    $testAddress = $LisCivicAddressType::GetById($address)
    Write-Host "Removing address $($testAddress.CivicAddressId)"
    if ($PSCmdlet.ShouldProcess($testAddress.CivicAddressId, 'Remove-CsOnlineLisCivicAddress')) {
        Remove-CsOnlineLisCivicAddress -CivicAddressId $testAddress.CivicAddressId
    }
    else {
        "Remove-CsOnlineLisCivicAddress -CivicAddressId $($testAddress.CivicAddressId)" | Write-Output
    }
}