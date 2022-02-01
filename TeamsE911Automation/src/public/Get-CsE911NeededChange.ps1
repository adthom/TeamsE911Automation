function Get-CsE911NeededChange {
    [CmdletBinding()]
    param (
        # Parameter help description
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object[]]
        $LocationConfiguration,

        [switch]
        $ForceOnlineCheck
    )

    begin {
        try {
            [Microsoft.TeamsCmdlets.Powershell.Connect.TeamsPowerShellSession]::ClientAuthenticated()
        }
        catch {
            throw "Run Connect-MicrosoftTeams prior to executing this script!"
        }

        # initialize caches
        $addressCache = @{}
        $locationCache = @{}
        $networkObjectCache = @{}
        $ProcessedNetworks = @{}

        $Rows = [Collections.Generic.List[object]]::new()

        # these are the changes which can span multiple rows, track this here (Get-CsE911LocationHashCode/Get-CsE911CivicAddressHashCode = array of change id + dependencies @(GUID(s)))
        $PendingChanges = @{}
        $ChangeObjects = [Collections.Generic.List[object]]::new()

        Write-Verbose "Populating Caches..."
        try {
            $addressCache = Get-CsLisCivicAddressCache -ErrorAction Stop
            Write-Verbose "Cached $($addressCache.Keys.Count) Civic Addresses"
            $locationCache = Get-CsLisLocationCache -ErrorAction Stop
            Write-Verbose "Cached $($locationCache.Keys.Count) Locations"
            $networkObjectCache = Get-CsLisNetworkObjectCache -ErrorAction Stop
            Write-Verbose "Cached $($networkObjectCache.Keys.Count) Network Objects"
        }
        catch {
            throw $_
        }

        if ($null -eq $script:azureHTTPClient) {
            $script:azureHTTPClient = [System.Net.Http.HttpClient]::new()
        }

        $StandardParams = @{
            InformationVariable = "InformationRecords"
            WarningVariable     = "WarningRecords"
            ErrorVariable       = "ErrorRecords"
        }

        Write-Verbose "Validating Rows..."
    }

    process {
        foreach ($lc in $LocationConfiguration) {
            $RowName = "$($lc.CompanyName):$($lc.Location)"
            Write-Verbose "Validating Object: $RowName..."

            if (!($HasChanges = Confirm-RowHasChanged -Row $lc)) {
                # no changes to this row since last processing, skip
                if (!$ForceOnlineCheck) {
                    Write-Verbose "$RowName has not changed - skipping..."
                    continue
                }
                Write-Verbose "$RowName has not changed but ForceOnlineCheck is set..."
            }

            # reset any warnings from previous run if we have detected changes
            if ($HasChanges -or $null -eq $lc.Warning) {
                $lc.Warning = ""
            }

            # validate row
            Write-Verbose "${RowName}: validating input..."
            if (!(Confirm-CsE911Input $lc @StandardParams)) {
                $Warnings = ($WarningRecords | Where-Object { !$lc.Warning.Contains($_) } ) -join ';'
                Write-Verbose "${RowName}: input invalid"
                if (!$HasChanges) {
                    Write-Verbose "${RowName}: aborting further processing"
                    continue
                }
                if ([string]::IsNullOrEmpty($lc.Warning)) {
                    $lc.Warning = $Warnings
                }
                else {
                    $lc.Warning += ";$Warnings"
                }
            }
            else {
                Write-Verbose "${RowName}: input valid"
            }

            $nHash = Get-CsE911NetworkObjectHashCode $lc
            if ($ProcessedNetworks.Keys -contains $nHash) {
                $ProcessedNetworks[$nHash] += $lc
            }
            else {
                $ProcessedNetworks.Add($nHash, @($lc)) | Out-Null
            }

            $Rows.Add($lc) | Out-Null
        }
    }

    end {
        Write-Verbose "Processing Rows..."
        # find duplicate network objects
        $DuplicatedNetworkObjects = $ProcessedNetworks.Values | Where-Object { $_.Count -gt 1 }
        if ($DuplicatedNetworkObjects.Count -gt 0) {
            Write-Warning "$($DuplicatedNetworkObjects.Count) conflicting network objects found!"
        }
        foreach ($ConflictedRow in $DuplicatedNetworkObjects) {
            $ConflictWarning = "DuplicateNetworkObject: $($ConflictedRow.NetworkObjectType): $($ConflictedRow.NetworkObjectIdentifier) exists in another row"
            if ([string]::IsNullOrEmpty($ConflictedRow.Warning)) {
                $ConflictedRow.Warning = $ConflictWarning
            }
            else {
                $ConflictedRow.Warning += ";$ConflictWarning"
            }
        }

        foreach ($Row in $Rows) {
            $RowName = "$($Row.CompanyName):$($Row.Location)"
            Write-Verbose "Processing $RowName..."
            # need to remove warning message for hashing... storing to re-add later
            $ExistingWarnings = $Row.Warning
            $Row.Warning = ""

            # build this objects so we can generate the Source update later
            $RowId = [Guid]::NewGuid().Guid

            $RowString = Get-CsE911RowString -Row $Row
            $RowHash = Get-CsE911RowHash -Row $Row
            $Row.Warning = $ExistingWarnings

            if ([string]::IsNullOrEmpty($Row.Warning)) {
                $RowDependencies = [Collections.Generic.List[string]]::new()
                $networkObjectHashCode = Get-CsE911NetworkObjectHashCode $Row
                if ($networkObjectHashCode -and $networkObjectCache.ContainsKey($networkObjectHashCode)) {
                    $CachedNetworkObject = $networkObjectCache[$networkObjectHashCode]
                    $validMatch = $Row | Confirm-NetworkObjectMatch -Cached $CachedNetworkObject -LocationCache $locationCache
                    if ($validMatch) {
                        Write-Verbose "${RowName}: NetworkObject Match Found!"
                        continue
                    }
                    Write-Verbose "${RowName}: NetworkObject exists, but has changed!"
                }
                else {
                    Write-Verbose "${RowName}: NetworkObject is new!"
                }
                # create change id:
                $NetworkChangeId = [Guid]::NewGuid().Guid
                $NetworkCommandParams = @{}
                $LocationCommandParams = @{}
                $AddressCommandParams = @{}
                $RowDependencies.Add($NetworkChangeId) | Out-Null
                $NetworkObjectDependencies = [Collections.Generic.List[string]]::new()

                $locationHashCode = Get-CsE911LocationHashCode $Row $Row.Location
                if ($locationHashCode -and $locationCache.ContainsKey($locationHashCode)) {
                    $CachedLocation = $locationCache[$locationHashCode]
                    $validMatch = $Row | Confirm-LocationMatch -Cached $CachedLocation
                    if ($validMatch) {
                        # create network object and point to found location id
                        Write-Verbose "${RowName}: Location Match Found!"
                        $NetworkCommandParams['LocationId'] = $CachedLocation.LocationId
                        # no need to create location, nulling out hash
                        $LocationCommandParams = $null
                    }
                    else {
                        Write-Verbose "${RowName}: Location exists, but has changed!"
                    }
                }
                else {
                    Write-Verbose "${RowName}: Location is new!"
                }

                if (!$NetworkCommandParams['LocationId'] -and $PendingChanges.ContainsKey($locationHashCode)) {
                    # No need to create new change, as we already have one pending, just create the network object
                    Write-Verbose "${RowName}: New Location command already created!"
                    $LocationChangeIds = $PendingChanges[$locationHashCode]
                    $LocationChangeId = $LocationChangeIds[0] # first entry is location change, any subsequent are child dependencies
                    $LocationIdVariableName = '$' + $LocationChangeId -replace '-', ''
                    $NetworkCommandParams['LocationId'] = '$(' + $LocationIdVariableName + '.LocationId)'
                    $NetworkObjectDependencies.AddRange($LocationChangeIds) | Out-Null
                    # no need to create location, nulling out hash
                    $LocationCommandParams = $null
                }
                if ($LocationCommandParams) {
                    $LocationChangeId = [Guid]::NewGuid().Guid
                    $LocationDependencies = [Collections.Generic.List[string]]::new()
                    $LocationIdVariableName = '$' + $LocationChangeId -replace '-', ''
                    $LocationCommandParams['LocationIdVariableName'] = $LocationIdVariableName
                    $NetworkCommandParams['LocationId'] = '$(' + $LocationIdVariableName + '.LocationId)'
                    $NetworkObjectDependencies.Add($LocationChangeId) | Out-Null
                }

                if ($LocationCommandParams) {
                    $addressHashCode = Get-CsE911CivicAddressHashCode $Row
                    if ($addressHashCode -and $addressCache.ContainsKey($addressHashCode)) {
                        $CachedCivicAddress = $addressCache[$addressHashCode]
                        $validMatch = $Row | Confirm-CivicAddressMatch -Cached $CachedCivicAddress
                        if ($validMatch) {
                            Write-Verbose "${RowName}: Address Match Found!"
                            $LocationCommandParams['CivicAddressId'] = $CachedCivicAddress.CivicAddressId
                            $AddressCommandParams = $null
                        }
                        else {
                            Write-Verbose "${RowName}: Address exists, but has changed!"
                        }
                    }
                    if (!$LocationCommandParams['CivicAddressId'] -and $PendingChanges.ContainsKey($addressHashCode)) {
                        # No need to create new change, as we already have one pending, just create the network object
                        Write-Verbose "${RowName}: New Address command already created!"
                        $CivicAddressChangeIds = $PendingChanges[$addressHashCode]
                        $CivicAddressChangeId = $CivicAddressChangeIds[0] # first entry is location change, any subsequent are child dependencies
                        $CivicAddressIdVariableName = '$' + $CivicAddressChangeId -replace '-', ''
                        $LocationCommandParams['CivicAddressId'] = '$(' + $CivicAddressIdVariableName + '.CivicAddressId)'
                        $LocationDependencies.AddRange($CivicAddressChangeIds) | Out-Null
                        $NetworkObjectDependencies.AddRange($CivicAddressChangeIds) | Out-Null
                        # no need to create location, nulling out hash
                        $AddressCommandParams = $null
                    }
                    if ($AddressCommandParams) {
                        $CivicAddressChangeId = [Guid]::NewGuid().Guid
                        $CivicAddressChangeIds = [Collections.Generic.List[string]]::new()
                        $CivicAddressIdVariableName = '$' + $CivicAddressChangeId -replace '-', ''
                        $AddressCommandParams['CivicAddressIdVariableName'] = $CivicAddressIdVariableName
                        $LocationCommandParams['CivicAddressId'] = '$(' + $CivicAddressIdVariableName + '.CivicAddressId)'
                        $LocationDependencies.Add($CivicAddressChangeId) | Out-Null
                        $NetworkObjectDependencies.Add($CivicAddressChangeId) | Out-Null
                        $ProcessInfo = $Row | Get-NewCivicAddressCommand @AddressCommandParams @StandardParams
                        if ($WarningRecords.Count -gt 0) {
                            $Warnings = $WarningRecords -join ';'
                            Write-Verbose "${RowName} is invalid! $Warnings"
                            if ([string]::IsNullOrEmpty($Row.Warning)) {
                                $Row.Warning = $Warnings
                            }
                            else {
                                $Row.Warning += ";$Warnings"
                            }
                        }

                        if ([string]::IsNullOrEmpty($Row.Warning)) {
                            $ChangeObject = [PSCustomObject]@{
                                Id          = $CivicAddressChangeId
                                UpdateType  = 'Online'
                                ProcessInfo = $ProcessInfo
                                DependsOn   = $CivicAddressChangeIds -join ';'
                            }
                            $ChangeObjects.Add($ChangeObject) | Out-Null
                            $CivicAddressChangeIds.Add($CivicAddressChangeId) | Out-Null
                            $PendingChanges.Add($addressHashCode, $CivicAddressChangeIds) | Out-Null
                        }
                    }

                    if ([string]::IsNullOrEmpty($Row.Warning)) {
                        $ChangeObject = [PSCustomObject]@{
                            Id          = $LocationChangeId
                            UpdateType  = 'Online'
                            ProcessInfo = $Row | Get-NewLocationCommand @LocationCommandParams
                            DependsOn   = $LocationDependencies -join ';'
                        }
                        $ChangeObjects.Add($ChangeObject) | Out-Null
                        $LocationDependencies.Insert(0, $LocationChangeId) | Out-Null
                        $PendingChanges.Add($locationHashCode, $LocationDependencies) | Out-Null
                    }
                }

                # create the network object change object and write to the output stream
                if ([string]::IsNullOrEmpty($Row.Warning)) {
                    $ChangeObject = [PSCustomObject]@{
                        Id          = $NetworkChangeId
                        UpdateType  = 'Online'
                        ProcessInfo = $Row | Get-NewNetworkObjectCommand @NetworkCommandParams
                        DependsOn   = $NetworkObjectDependencies -join ';'
                    }
                    $ChangeObjects.Add($ChangeObject) | Out-Null
                    # add change ids to the total row dependencies
                    foreach ($ChangeDependency in $NetworkObjectDependencies) {
                        if (!$RowDependencies.Contains($ChangeDependency)) {
                            $RowDependencies.Add($ChangeDependency) | Out-Null
                        }
                    }
                }
            }
            else {
                Write-Verbose "${RowName}: has warnings, skipping further processing!"
            }

            $RowString = Get-CsE911RowString -Row $Row     # rebuild row string to capture any added warnings
            $ChangeObject = [PSCustomObject]@{
                Id          = $RowId
                UpdateType  = 'Source'
                ProcessInfo = @($RowHash, $RowString) -join ';'
                DependsOn   = $RowDependencies -join ';'
            }
            $ChangeObjects.Add($ChangeObject) | Out-Null
        }

        $ChangeObjects | Write-Output
    }
}
