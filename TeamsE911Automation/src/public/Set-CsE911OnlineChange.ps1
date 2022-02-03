function Set-CsE911OnlineChange {
    [CmdletBinding()]
    param (
        # Parameter help description
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object[]]
        $PendingChange
    )
    begin {
        try {
            [Microsoft.TeamsCmdlets.Powershell.Connect.TeamsPowerShellSession]::ClientAuthenticated()
        }
        catch {
            throw "Run Connect-MicrosoftTeams prior to executing this script!"
        }
        $DependencyLists = [Collections.Generic.List[object]]::new()
    }
    process {
        # build dependency tree for each change
        foreach ($Change in $PendingChange) {
            # intialize variables for loop
            $ChangeIndex = -1
            $DependencyList = $null
            $Id = $Change.Id
            $DependsOnIds = Get-DependencyListFromString $Change
            foreach ($DependencyId in $DependsOnIds) {
                if ($ChangeIndex -eq -1) {
                    # check if this already has a matching dependency, find the index where this dependency is listed
                    $DependencyList = $DependencyLists | Where-Object { $_ | Where-Object { $DependencyId -in $_.Id -or $DependencyId -in (Get-DependencyListFromString $_) } }
                    if ($DependencyList) {
                        for ($i = 0; $i -lt $DependencyLists.Count; $i++) {
                            $List = $DependencyLists[$i]
                            if ($DependencyId -in $List.Id -or $DependencyId -in (Get-DependencyListFromString $List)) {
                                $ChangeIndex = $i
                                $DependencyList = $List
                                break
                            }
                        }
                    }
                }
            }
            # insert change into dependency array before any depending changes and after any dependent changes
            $ChangeBeforeThisChange = @($DependencyList | Where-Object { $_ -and $_.Id -in $DependsOnIds -and $_.Id -ne $Id })
            $ChangeAfterThisChange = @($DependencyList | Where-Object { $_ -notin $ChangeBeforeThisChange } | Where-Object { $_ -and $Change.Id -in (Get-DependencyListFromString $_) -and $_.Id -ne $Id })
            $OtherChanges = @($DependencyList | Where-Object { $_ -and $_ -notin $ChangeBeforeThisChange -and $_ -notin $ChangeAfterThisChange -and $_.Id -ne $Id })
            $DependencyList = [Collections.Generic.List[object]]::new()
            if ($ChangeBeforeThisChange -and $ChangeBeforeThisChange.Count -gt 0) {
                $DependencyList.AddRange($ChangeBeforeThisChange) | Out-Null
            }
            $DependencyList.Add($Change) | Out-Null
            if ($OtherChanges -and $OtherChanges.Count -gt 0) {
                $DependencyList.AddRange($OtherChanges) | Out-Null
            }
            if ($ChangeAfterThisChange -and $ChangeAfterThisChange.Count -gt 0) {
                $DependencyList.AddRange($ChangeAfterThisChange) | Out-Null
            }
            if ($ChangeIndex -ge 0) {
                $DependencyLists[$ChangeIndex] = $DependencyList
            }
            else {
                $ChangeIndex = $DependencyLists.Count + 1
                $DependencyLists.Add($DependencyList) | Out-Null
            }
        }
    }
    end {
        # process pending changes
        foreach ($ChangeList in $DependencyLists) {
            $HasErrored = $false
            $WarningVar = ""
            $ProcessedChanges = [Collections.Generic.List[object]]::new()
            $SourceChanges = [Collections.Generic.List[object]]::new()
            foreach ($Change in $ChangeList) {
                if ($Change.UpdateType -eq 'Online') {
                    $ChangeCommand = $Change.ProcessInfo
                    try {
                        Write-Verbose $ChangeCommand
                        $CommandScript = [ScriptBlock]::Create($ChangeCommand)
                        Invoke-Command -ScriptBlock $CommandScript -NoNewScope -ErrorAction Stop | Out-Null
                        $ProcessedChanges.Add($Change) | Out-Null
                    }
                    catch {
                        $HasErrored = $true
                        $ErrorMessage = "OnlineChangeError: Command: { $ChangeCommand } ErrorMessage: $($_.Exception.Message)"
                        Write-Warning $ErrorMessage
                        $WarningVar = if ($WarningVar.Length -eq 0) { $ErrorMessage } else { $WarningVar + ';' + $ErrorMessage }
                    }
                }
                else {
                    Write-Verbose "Source Change $($Change.ProcessInfo)"
                    $SourceChanges.Add($Change) | Out-Null
                }
            }
            if ($HasErrored) {
                foreach ($SourceChange in $SourceChanges) {
                    $completed = $true
                    $SourceHash, $SourceString = $SourceChange.ProcessInfo -split ';', 2
                    foreach ($Dependency in (Get-DependencyListFromString $SourceChange)) {
                        if ($Dependency -notin $ProcessedChanges.Id) {
                            $completed = $false
                            break
                        }
                    }
                    if ($completed) {
                        $SourceChange | Write-Output
                    }
                    else {
                        $SourceObject = $SourceString | ConvertFrom-Json
                        $SourceObject.Warning = if ([string]::IsNullOrEmpty($SourceObject.Warning)) { $WarningVar } else { $SourceObject.Warning + ';' + $WarningVar }
                        $SourceString = Get-CsE911RowString -Row $SourceObject
                        $NewSourceChange = [PSCustomObject]@{
                            Id          = $SourceChange.Id
                            UpdateType  = $SourceChange.UpdateType
                            ProcessInfo = @($SourceHash, $SourceString) -join ';'
                            DependsOn   = $SourceChange.DependsOn
                        }
                        $NewSourceChange | Write-Output
                    }
                }
            }
            else {
                $SourceChanges | Write-Output
            }
        }
    }
}
