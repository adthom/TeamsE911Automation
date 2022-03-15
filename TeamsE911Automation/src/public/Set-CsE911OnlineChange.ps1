function Set-CsE911OnlineChange {
    [CmdletBinding()]
    param (
        # Parameter help description
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object[]]
        $PendingChange
    )
    begin {
        $vsw = [Diagnostics.Stopwatch]::StartNew()
        Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] Beginning..."

        try {
            [Microsoft.TeamsCmdlets.Powershell.Connect.TeamsPowerShellSession]::ClientAuthenticated()
        }
        catch {
            throw "Run Connect-MicrosoftTeams prior to executing this script!"
        }
        $DependencyTrees = [Collections.Generic.List[object]]::new()
        $DependencyLists = [Collections.Generic.List[object]]::new()
        $PendingChanges = [Collections.Generic.List[object]]::new()
    }
    process {
        foreach ($Change in $PendingChange) {
            if ([string]::IsNullOrEmpty($Change.DependsOn)) {
                # validate this is a proper object, if not, pass through pipeline (out of order)
                if ([string]::IsNullOrEmpty($Change.Id)) {
                    Write-Warning "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] $Change is not a valid pending change object!"
                    Write-Output -InputObject $Change
                    continue
                }

                # this is a root level change, add as root node
                Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] Adding pending change with ID of $($Change.Id) as a root of a dependency tree"
                [void]$DependencyTrees.Add(
                    [PSCustomObject]@{
                        Change   = $Change
                        Children = [Collections.Generic.List[object]]::new()
                    })
                continue
            }
            [void]$PendingChanges.Add(
                [PSCustomObject]@{
                    Change   = $Change
                    Children = [Collections.Generic.List[object]]::new()
                })
        }
    }
    end {
        if ($DependencyTrees.Count -eq 0) {
            Write-Warning "No pending online changes found!"
            return
        }
        $i = 1
        while ($true) {
            Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] Adding pending changes with $i dependencies to their dependency tree"
            $ChildDependencies = $PendingChanges.Where({ $_.Change.DependsOn.Split(';').Count -eq $i })
            if ($ChildDependencies.Count -eq 0) {
                break
            }
            foreach ($Child in $ChildDependencies) {
                $WalkStack = [Collections.Generic.Stack[object]]::new()
                $RootTrees = $DependencyTrees.Where({ $Child.Change.DependsOn.IndexOf($_.Change.Id) -gt -1 })
                $TreesToPlace = $RootTrees.Count
                # this should always be 1...
                foreach ($Tree in $RootTrees) {
                    [void]$WalkStack.Push($Tree)
                }
                while ($WalkStack.Count -gt 0 -and $TreesToPlace -gt 0) {
                    $Current = $WalkStack.Pop()
                    if ($Child.Change.DependsOn.IndexOf($Current.Change.Id) -gt -1) {
                        # find any child node of current node upon which we depend
                        $ChildrenTrees = $Current.Children.Where({ $Child.Change.DependsOn.IndexOf($_.Change.Id) -gt -1 })
                        foreach ($ChildTree in $ChildrenTrees) {
                            # add found child node dependencies to the stack (should never be more than one)
                            [void]$WalkStack.Push($ChildTree)
                        }
                        # if we found a child node dependency, continue processing the stack
                        if ($ChildrenTrees.Count -gt 0) { continue }
                        # we have found where to place this node, add as child to current
                        [void]$Current.Children.Add($Child)
                        $TreesToPlace--
                    }
                }
            }
            $i++
        }

        foreach ($Tree in $DependencyTrees) {
            Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] Turning dependency tree with root ID of $($Tree.Change.Id) into list"
            $DependencyList = [Collections.Generic.List[object]]::new()
            $WalkStack = [Collections.Generic.Stack[object]]::new()
            [void]$DependencyList.Add($Tree.Change)
            [void]$WalkStack.Push($Tree)
            while ($WalkStack.Count -gt 0) {
                $Current = $WalkStack.Pop()
                foreach ($Child in $Current.Children) {
                    [void]$DependencyList.Add($Child.Change)
                    [void]$WalkStack.Push($Child)
                }
            }
            [void]$DependencyLists.Add($DependencyList)
        }

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
                        Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] $ChangeCommand"
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
                    Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] Source Change $($Change.ProcessInfo)"
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

        $vsw.Stop()
        Write-Verbose "[$($vsw.Elapsed.TotalMilliseconds.ToString('F3'))] [$($MyInvocation.MyCommand.Name)] Finished"
    }
}
