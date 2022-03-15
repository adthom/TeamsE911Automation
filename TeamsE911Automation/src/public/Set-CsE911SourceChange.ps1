function Set-CsE911SourceChange {
    [CmdletBinding()]
    param (
        # Parameter help description
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object[]]
        $PendingChange,

        # Parameter help description
        [Parameter(Mandatory = $true)]
        [object[]]
        $RawInput
    )
    begin {
        $vsw = [Diagnostics.Stopwatch]::StartNew()
        Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] Beginning..."

        $PendingSourceChanges = [Collections.Generic.List[object]]::new()
        $PendingSourceChangeRowHashes = @{}
        $FoundBlockingOnlineChanges = [Collections.Generic.List[string]]::new()
        $OnlineChangesThatCouldBlock = [Collections.Generic.List[string]]::new()

        # # Prepare RawInput for evaulation
        # # We only need to look to update input rows where changes have occurred
        # $UnchangedRows = $RawInput.Where({ !(Confirm-RowHasChanged -Row $_) })
        # # write rows to outputstream early
        # Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] Rows unchanged: $($UnchangedRows.Count)"
        # $UnchangedRows | Write-Output

        # $UnprocessedRows = $RawInput.Where({ $_ -notin $UnchangedRows })
        $UnprocessedRows = $RawInput
        $UnprocessedRowHash = @{}
        foreach ($Row in $UnprocessedRows) {
            $RowHash = Get-CsE911RowHash -Row $Row
            $UnprocessedRowHash[$RowHash] = $Row
        }
    }
    process {
        :nextChange foreach ($Change in $PendingChange) {
            if ($Change.UpdateType -ne 'Source') {
                # this online change is still pending, add as a blocking dependency
                $FoundBlockingOnlineChanges.Add($Change.Id) | Out-Null

                # if we already found a pending source update that would be blocked by this pending online change,
                # find the source change and remove it from the list of pending changes
                # this is needed to ensure that ordering of the input stream won't cause erroneous updates
                if ($OnlineChangesThatCouldBlock.Contains($Change.Id)) {
                    $BlockedChange = $PendingSourceChanges | Where-Object { $Change.Id -in $_.ExpandedDependsOn }
                    if ($BlockedChange) {
                        # need to remove blocked change
                        $PendingSourceChanges.Remove($BlockedChange) | Out-Null
                        $PendingSourceChangeRowHashes.Remove($BlockedChange.EntryHash) | Out-Null
                    }
                }
                continue nextChange
            }
            $RowHash, $RowString = $Change.ProcessInfo -split ';', 2
            # get online changes this source change depends on
            $DependsOn = $Change.DependsOn -split ';'
            $OnlineChangesThatCouldBlock.AddRange($DependsOn) | Out-Null

            # check our blocking change list to see if this source update has any parent dependencies
            foreach ($Dependency in $DependsOn) {
                if ($FoundBlockingOnlineChanges.Contains($Dependency)) {
                    # Source update still has pending dependency, skipping update
                    continue nextChange
                }
                # add dependency to list of changes that could block
                # this is needed to ensure that ordering of the input stream won't cause erroneous updates
                $OnlineChangesThatCouldBlock.Add($Dependency) | Out-Null
            }
            # convert json string to object, adding an array of dependencies
            $PotentialChange = $RowString | ConvertFrom-Json | Select-Object -Property *, @{Name = 'EntryHash'; Expression = { $RowHash } }, @{Name = 'ExpandedDependsOn'; Expression = { $DependsOn } } -ExcludeProperty EntryHash
            # add pending change to the list
            $PendingSourceChanges.Add($PotentialChange) | Out-Null
            $PendingSourceChangeRowHashes.Add($RowHash, $RowString) | Out-Null
        }
    }

    end {
        # output rows that have changed
        # removing the created dependency array
        Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] Rows updated: $($PendingSourceChanges.Count)"
        $PendingSourceChanges | Select-Object -Property * -ExcludeProperty ExpandedDependsOn | Write-Output

        foreach ($RowHash in $PendingSourceChangeRowHashes.Keys) {
            $UnprocessedRowHash.Remove($RowHash) | Out-Null
        }
        # output any remaining unprocessed rows where there is no dependency without updating the row hash
        Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] Rows not yet processed or unchanged: $($UnprocessedRowHash.Values.Count)"
        $UnprocessedRowHash.Values | Write-Output

        $vsw.Stop()
        Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] Finished"
    }
}

