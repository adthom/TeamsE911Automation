function Invoke-ThreadedTeamsJob {
    [CmdletBinding()]
    param (
        [object[]]
        $Batches,

        [int]
        $MaximumThreads = 32,

        [int]
        $UpdateInterval = 120,

        [Hashtable]
        $CommandStatus,

        [Hashtable]
        $State
    )
    begin {
        try {
            [Microsoft.TeamsCmdlets.Powershell.Connect.TeamsPowerShellSession]::ClientAuthenticated()
        }
        catch {
            throw "You must run Connect-MicrosoftTeams first!"
        }

        function GetTimeString {
            param (
                $Seconds
            )
            $TimeString = "$([Math]::Round($Seconds,1)) seconds"
            if ($Seconds -ge 60 -and $Seconds -lt 3600) {
                $TimeString = "$([Math]::Round($Seconds/60,2)) minutes"
            }
            if ($Seconds -ge 3600) {
                $TimeString = "$([Math]::Round($Seconds/3600,2)) hours"
            }
            return $TimeString
        }

        function StatusUpdate {
            param (
                $_sync,
                $Jobs
            )

            Write-Host ""
            Write-Host "Status Update: $([DateTime]::Now)"
            if ($_sync.JobStatus.Pending -gt 0) { Write-Host "Jobs Pending: $($_sync.JobStatus.Pending)" }
            if ($_sync.JobStatus.Running -gt 0) { Write-Host "Jobs Running: $($_sync.JobStatus.Running)" }
            if ($_sync.JobStatus.Completed -gt 0) { Write-Host "Jobs Completed: $($_sync.JobStatus.Completed)" }
            if ($_sync.JobStatus.Errored -gt 0) { Write-Host "Jobs Errored: $($_sync.JobStatus.Errored)" }
            foreach ($Key in $_sync.CommandStatus.Keys) {
                if ($_sync.CommandStatus[$Key].Value -gt 0) {
                    Write-Host "$($_sync.CommandStatus[$Key].Description): $($_sync.CommandStatus[$Key].Value)"
                }
            }
            $Hash = @{
                TotalElapsed      = ([DateTime]::Now - $_sync.StartTime).TotalSeconds
                PreviousCompleted = $_sync.PreviousCompleted
                PreviousElapsed   = $_sync.PreviousElapsed
            }
            if ($null -ne $_sync.CommandStatus -and $null -ne $_sync.CommandStatus.Completed) {
                $Hash['Completed'] = $_sync.CommandStatus.Completed.Value
                $Hash['Total'] = $_sync.CommandStatus.Completed.Value + $_sync.CommandStatus.Pending.Value
            }
            else {
                $Hash['Completed'] = $_sync.JobStatus.Completed
                $Hash['Total'] = $_sync.JobStatus.Completed + $_sync.JobStatus.Pending
            }
            $_sync.PreviousCompleted = $Hash['Completed']
            $_sync.PreviousElapsed = $Hash['TotalElapsed']
            $CurrentStatus = [PSCustomObject]$Hash
            $TotalSeconds = $CurrentStatus.TotalElapsed
            $SegmentSeconds = $TotalSeconds - $CurrentStatus.PreviousElapsed
            $NeededChanges = $CurrentStatus.Total
            $Completed = $CurrentStatus.Completed
            $ChangesInLast = $Completed - $CurrentStatus.PreviousCompleted
            if ($ChangesInLast -gt 0) {
                $ElapsedTimeString = GetTimeString $SegmentSeconds
                Write-Host "$ChangesInLast changes performed in last $ElapsedTimeString ($([Math]::Round($ChangesInLast/$SegmentSeconds,2))/s)"
            }
            if ($Completed -gt 0) {
                $TotalTimeString = GetTimeString $TotalSeconds
                Write-Host "$Completed total changes performed in $TotalTimeString ($([Math]::Round($Completed/$TotalSeconds,2))/s)"
                Write-Host "$($NeededChanges - $Completed) remaining - $([Math]::Round(100*($Completed/$NeededChanges),2))% complete"
            }
            foreach ($Job in $Jobs) {
                $InfoRecords = if ($null -ne $Job.PowerShell.Streams.Information -and $Job.PowerShell.Streams.Information.Count -gt 0) {
                    $Job.PowerShell.Streams.Information.ReadAll()
                }
                foreach ($i in $InfoRecords) {
                    if (![string]::IsNullOrWhiteSpace($i.MessageData)) {
                        if ($i.Source -match 'Microsoft\.Teams\.Config') { continue }
                        Write-Host "Job $($Job.Id): $($i.MessageData)"
                    }
                }
                $WarningRecords = if ($null -ne $Job.PowerShell.Streams.Warning -and $Job.PowerShell.Streams.Warning.Count -gt 0) {
                    $Job.PowerShell.Streams.Warning.ReadAll()
                }
                foreach ($i in $WarningRecords) {
                    if (![string]::IsNullOrWhiteSpace($i.Message)) {
                        Write-Warning "Job $($Job.Id): $($i.Message)"
                    }
                }
                $ErrorRecords = if ($null -ne $finishedJob.PowerShell.Streams.Error -and $finishedJob.PowerShell.Streams.Error.Count -gt 0) {
                    $finishedJob.PowerShell.Streams.Error.ReadAll()
                }
                foreach ($i in $ErrorRecords) {
                    Write-Warning -Message "Job $($Job.Id): Unhandled exception.`r`nException: $($i.Exception.Message)"
                    if ($null -ne $i.InvocationInfo) {
                        Write-Warning -Message "Invocation Line: $($i.InvocationInfo.Line)"
                        Write-Warning -Message "Script Line Number: $($i.InvocationInfo.ScriptLineNumber)"
                    }
                    $inner = $i.Exception.InnerException
                    while ($null -ne $inner) {
                        Write-Warning -Message "Inner Exception: $($inner.Message)"
                        $inner = $inner.InnerException
                    }
                }
            }
        }

        $BaseScript = @'
$_sync.JobStatus.Pending--
$_sync.JobStatus.Running++
try {{
    try {{
        [Microsoft.TeamsCmdlets.Powershell.Connect.TeamsPowerShellSession]::ClientAuthenticated()
        $Connected = $true
    }}
    catch {{
        $Connected = $false
        Import-Module -Name MicrosoftTeams -ErrorAction Stop | Out-Null
    }}
    if (!$Connected) {{
        Connect-MicrosoftTeams -AccessTokens ($_sync.TokenCache.Values.AccessToken) -ErrorAction Stop | Out-Null
        [Microsoft.TeamsCmdlets.PowerShell.Connect.TokenProvider.AccessTokenCache]::AccessTokens = $_sync.TokenCache
        [Microsoft.TeamsCmdlets.Powershell.Connect.TeamsPowerShellSession]::SessionProvider.PublicClientApplication = $_sync.Application
    }}
    $NewOutput = {0}

    if ($null -ne $NewOutput) {{
        [void]$_sync.Results.Add($NewOutput)
    }}
}}
catch {{
    Write-Warning "Job failed: $($_.Exception.Message)"
    Write-Warning "$($_.InvocationInfo.InvocationName) - '$($_.InvocationInfo.Line.Trim())' - $($_.Exception.GetType().FullName)"
    $_sync.JobStatus.Errored++
}}
finally {{
    $_sync.JobStatus.Running--
    $_sync.JobStatus.Completed++
}}
'@
    }
    end {
        $Runspaces = [Collections.Generic.List[System.Management.Automation.Runspaces.Runspace]]::new()
        $MaxRunspaces = [Math]::Min($MaximumThreads, $Batches.Count)

        $JobStatus = [PSCustomObject]@{
            Pending   = $Batches.Count
            Running   = 0
            Completed = 0
            Errored   = 0
        }

        $Concurrency = [Math]::Max([Math]::Floor(($MaxRunspaces + 1) / 4), 2)
        $_sync = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new($Concurrency, 11)
        $_sync.JobStatus = $JobStatus
        $_sync.Results = [Collections.Generic.List[object]]::new()
        $_sync.TokenCache = [Microsoft.TeamsCmdlets.PowerShell.Connect.TokenProvider.AccessTokenCache]::AccessTokens
        $_sync.Application = [Microsoft.TeamsCmdlets.Powershell.Connect.TeamsPowerShellSession]::SessionProvider.PublicClientApplication
        $_sync.StartTime = [DateTime]::Now
        $_sync.PreviousElapsed = 0.0
        $_sync.PreviousCompleted = 0
        
        if ($null -ne $CommandStatus) {
            $_sync.CommandStatus = $CommandStatus
        }
        if ($null -ne $SharedState) {
            $_sync.SharedState = $SharedState
        }

        #Create the sessionstate variable entry
        $hVar = [System.Management.Automation.Runspaces.SessionStateVariableEntry]::new('_sync', $_sync, $null)
        $InitialSessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
        #Add the variable to the sessionstate
        $InitialSessionState.Variables.Add($hVar)

        for ($i = 0; $i -lt $MaxRunspaces; $i++) {
            $newRunspace = [RunspaceFactory]::CreateRunspace($InitialSessionState)
            $newRunspace.Open()
            $Runspaces.Add($newRunspace)
        }
        try {
            $Jobs = [Collections.Generic.List[object]]::new()
            $curr = [DateTime]::Now
            for ($i = 0; $i -lt $Batches.Count; $i++) {
                $newJob = [PSCustomObject]@{
                    Id         = $Batches[$i].Id
                    PowerShell = [PowerShell]::Create()
                    Handle     = $null
                }
                $Runspace = $Runspaces.Where({ $_.RunspaceAvailability -eq 'Available' }, 'First', 1)[0]
                if (([DateTime]::Now - $curr).TotalSeconds -ge $UpdateInterval -or $i -in @(0, ($Runspaces.Count - 1), ($Batches.Count - 1))) {
                    $curr = [DateTime]::Now
                    StatusUpdate $_sync $Jobs
                }
                while ($null -eq $Runspace) {
                    Start-Sleep -Milliseconds 100
                    if (([DateTime]::Now - $curr).TotalSeconds -ge $UpdateInterval) {
                        $curr = [DateTime]::Now
                        StatusUpdate $_sync $Jobs
                    }
                    $Runspace = $Runspaces.Where({ $_.RunspaceAvailability -eq 'Available' }, 'First', 1)[0]
                }
                $newJob.PowerShell.Runspace = $Runspace
                $newJob.PowerShell.AddScript(($BaseScript -f $Batches[$i].Script)) | Out-Null
                $newJob.Handle = $newJob.PowerShell.BeginInvoke()
                $Jobs.Add($newJob) | Out-Null
            }
            do {
                if (([DateTime]::Now - $curr).TotalSeconds -ge $UpdateInterval) {
                    $curr = [DateTime]::Now
                    StatusUpdate $_sync $Jobs
                }
                Start-Sleep -Milliseconds 100
            } while ($Jobs.Where({ $_.Handle.IsCompleted }).Count -lt $Jobs.Count)

            StatusUpdate $_sync $Jobs
            $_sync.Results | Write-Output
        }
        finally {
            for ($i = 0; $i -lt $Runspaces.Count; $i++) {
                $Runspaces[$i].Dispose()
            }
            $Runspaces.Clear()
            for ($i = 0; $i -lt $Jobs.Count; $i++) {
                $Jobs[$i].PowerShell.Dispose()
                $Jobs[$i].Handle = $null
                $Jobs[$i].PowerShell = $null
            }
            $Jobs.Clear()
        }
    }
}
function Invoke-CsE911BulkOnlineChange {
    param (
        $Changes,

        [int]
        $MaxJobs = 32
    )
    end {
        $Online = $Changes.Where({ $_.UpdateType -eq 'Online' })
        $RootChanges = $Online.Where({ $_.DependsOn.Count() -eq 0 })

        $OnlineQueues = @{}
        foreach ($rc in $RootChanges) {
            $id = $rc.Id.ToString()
            [void]$OnlineQueues.Add($id, [Collections.Generic.Queue[object]]::new())
            [void]$OnlineQueues[$id].Enqueue($rc.ProcessInfo.ToString())
        }
        for ($i = 1; $i -lt 5; $i++) {
            $NextChanges = $Online.Where({ $_.DependsOn.Count() -eq $i })
            foreach ($nc in $NextChanges) {
                $main = $nc.DependsOn.GetEnumerator().Where({ $true }, 'First', 1)[0].ToString()
                [void]$OnlineQueues[$main].Enqueue($nc.ProcessInfo.ToString())
            }
        }
        $HashBySize = @{}
        $OnlineQueues.GetEnumerator() | ForEach-Object { 
            if (!$HashBySize.ContainsKey($_.Value.Count)) { 
                $HashBySize[$_.Value.Count] = [Collections.Generic.List[Collections.Generic.Queue[object]]]::new()
            }
            $HashBySize[$_.Value.Count].Add($_.Value)
        }
        $Sum = $OnlineQueues.GetEnumerator() | ForEach-Object { $_.Value.Count } | Measure-Object -Sum | Select-Object -ExpandProperty Sum
        $Count = $OnlineQueues.Count
        $GroupCount = [Math]::Min($Count, ($MaxJobs - 1))
        $MaxSize = $OnlineQueues.GetEnumerator() | ForEach-Object { $_.Value.Count } | Sort-Object -Descending | Select-Object -First 1
        $GroupSize = [Math]::Max($MaxSize, ([Math]::Floor($Sum / $GroupCount)))
        $Batches = @{}
        $batch = 1
        $GroupJob = $HashBySize.GetEnumerator() | Sort-Object -Property Key -Descending | Where-Object { $_.Value.Count -gt 0 } | Select-Object -First 1 | ForEach-Object { $_.Value } | Select-Object -First 1
        while ($null -ne $GroupJob) {
            $Batches[$batch] = [Collections.Generic.List[Collections.Generic.Queue[object]]]::new()
            [void]$Batches[$batch].Add($GroupJob)
            [void]$HashBySize[$GroupJob.Count].Remove($GroupJob)
            $currSize = $GroupJob.Count
            while ($currSize -lt $GroupSize) {
                $nextGroup = $HashBySize.GetEnumerator() | Sort-Object -Property Key -Descending | Where-Object { $_.Value.Count -gt 0 -and ($_.Key + $currSize) -le $GroupSize } | Select-Object -First 1 | ForEach-Object { $_.Value } | Select-Object -First 1
                if ($null -eq $nextGroup) { break }
                [void]$Batches[$batch].Add($nextGroup)
                [void]$HashBySize[$nextGroup.Count].Remove($nextGroup)
                $currSize += $nextGroup.Count
            }
            $GroupJob = $HashBySize.GetEnumerator() | Sort-Object -Property Key -Descending | Where-Object { $_.Value.Count -gt 0 } | Select-Object -First 1 | ForEach-Object { $_.Value } | Select-Object -First 1
            $batch++
        }
        ProcessBatches -Batches $Batches
    }
}
function Invoke-CsE911BulkRemoval {
    param (
        [int]
        $MaxJobs = 32
    )
    end {
        Write-Host "Getting Current Subnets: " -NoNewline
        $Subnets = @(Get-CsOnlineLisSubnet).Where({ $_.Subnet })
        Write-Host "Found $($Subnets.Count)"
        Write-Host "Getting Current Switches: " -NoNewline
        $Switches = @(Get-CsOnlineLisSwitch).Where({ $_.ChassisId })
        Write-Host "Found $($Switches.Count)"
        Write-Host "Getting Current Ports: " -NoNewline
        $Ports = @(Get-CsOnlineLisPort).Where({ $_.ChassisId -and $_.PortId })
        Write-Host "Found $($Ports.Count)"
        Write-Host "Getting Current Wireless Access Points: " -NoNewline
        $WirelessAccessPoints = @(Get-CsOnlineLisWirelessAccessPoint).Where({ $_.Bssid })
        Write-Host "Found $($WirelessAccessPoints.Count)"
        Write-Host "Getting Current Civic Addresses: " -NoNewline
        $Addresses = @(Get-CsOnlineLisCivicAddress -PopulateNumberOfVoiceUsers -PopulateNumberOfTelephoneNumbers)
        Write-Host "Found $($Addresses.Count)"
        Write-Host "Getting Current Locations: " -NoNewline
        $Locations = @(Get-CsOnlineLisLocation).Where({ $Location = $_; $addr = $Addresses.Where({ $_.CivicAddressId -eq $Location.CivicAddressId -and $Location.LocationId -ne $_.DefaultLocationId }); $null -ne $addr -and $addr.Count -gt 0 })
        Write-Host "Found $($Locations.Count)"

        $Commands = [Collections.Generic.List[string]]::new()
        foreach ($Subnet in $Subnets) {
            [void]$Commands.Add(('Remove-CsOnlineLisSubnet -Subnet ''{0}'' -ErrorAction Stop | Out-Null' -f $Subnet.Subnet))
        }
        foreach ($Port in $Ports) {
            [void]$Commands.Add(('Remove-CsOnlineLisPort -PortId ''{0}'' -ChassisId ''{1}'' -ErrorAction Stop | Out-Null' -f $Port.PortId, $Port.ChassisId))
        }
        foreach ($Switch in $Switches) {
            [void]$Commands.Add(('Remove-CsOnlineLisSwitch -ChassisId ''{0}'' -ErrorAction Stop | Out-Null' -f $Switch.ChassisId))
        }
        foreach ($WAP in $WirelessAccessPoints) {
            [void]$Commands.Add(('Remove-CsOnlineLisWirelessAccessPoint -Bssid ''{0}'' -ErrorAction Stop | Out-Null' -f $WAP.Bssid))
        }

        $LocationCommands = [Collections.Generic.List[string]]::new()
        foreach ($Location in $Locations) {
            [void]$LocationCommands.Add(('Remove-CsOnlineLisLocation -LocationId ''{0}'' -ErrorAction Stop | Out-Null' -f $Location.LocationId))
        }
        $AddressCommands = [Collections.Generic.List[string]]::new()
        foreach ($Address in $Addresses) {
            if ($Address.NumberOfVoiceUsers -gt 0 -or $Address.NumberOfTelephoneNumbers -gt 0 ) { continue }
            [void]$AddressCommands.Add(('Remove-CsOnlineLisCivicAddress -CivicAddressId ''{0}'' -ErrorAction Stop | Out-Null' -f $Address.CivicAddressId))
        }

        $CommandsPerJobMin = 150
        $GroupCount = [Math]::Min([Math]::Floor($Commands.Count / $CommandsPerJobMin), ($MaxJobs - 1))
        $Batches = @{}
        for ($i = 1; $i -le ($GroupCount + 1); $i++) {
            $Batches[$i] = [Collections.Generic.List[string]]::new()
        }
        for ($i = 0; $i -lt $Commands.Count;) {
            foreach ($k in $Batches.Keys) {
                if ($i -eq $Commands.Count) {
                    break
                }
                [void]$Batches[$k].Add($Commands[$i])
                $i++
            }
        }

        $GroupCount = [Math]::Min([Math]::Floor($LocationCommands.Count / $CommandsPerJobMin), ($MaxJobs - 1))
        $LocationBatches = @{}
        for ($i = 1; $i -le ($GroupCount + 1); $i++) {
            $LocationBatches[$i] = [Collections.Generic.List[string]]::new()
        }
        for ($i = 0; $i -lt $LocationCommands.Count; $i++) {
            foreach ($k in $LocationBatches.Keys) {
                if ($i -eq $LocationCommands.Count) {
                    break
                }
                [void]$LocationBatches[$k].Add($LocationCommands[$i])
                $i++
            }
        }

        $GroupCount = [Math]::Min([Math]::Floor($AddressCommands.Count / $CommandsPerJobMin), ($MaxJobs - 1))
        $AddressBatches = @{}
        for ($i = 1; $i -le ($GroupCount + 1); $i++) {
            $AddressBatches[$i] = [Collections.Generic.List[string]]::new()
        }
        for ($i = 0; $i -lt $AddressCommands.Count; $i++) {
            foreach ($k in $AddressBatches.Keys) {
                if ($i -eq $AddressCommands.Count) {
                    break
                }
                [void]$AddressBatches[$k].Add($AddressCommands[$i])
                $i++
            }
        }

        if ($Commands.Count -gt 0) {
            Write-Host "Removing Network Objects"
            ProcessBatches -Batches $Batches
            Write-Host ""
        }
        if ($LocationCommands.Count -gt 0) {
            Write-Host "Removing Locations"
            ProcessBatches -Batches $LocationBatches
            Write-Host ""
        }
        if ($AddressCommands.Count -gt 0) {
            Write-Host "Removing Civic Addresses"
            ProcessBatches -Batches $AddressBatches
        }
    }
}
function ProcessBatches {
    param (
        [Hashtable]
        $Batches
    )
    begin {
        $UpdateFrequency = 60
    }
    end {
        $BatchSB = [Text.StringBuilder]::new()
        $Keys = [int[]]::new($Batches.Keys.Count)
        $Batches.Keys.CopyTo($Keys, 0)
        foreach ($Key in $Keys) {
            if ($Batches[$Key].Count -eq 0) {
                [void]$Batches.Remove($Key)
            }
        }

        $CommandStatus = [ordered]@{
            Pending   = [PSCustomObject]@{
                Description = "Commands Pending"
                Value       = 0
            }
            Completed = [PSCustomObject]@{
                Description = "Commands Completed"
                Value       = 0
            }
            Skipped = [PSCustomObject]@{
                Description = "Commands Skipped"
                Value       = 0
            }
            Errored   = [PSCustomObject]@{
                Description = "Commands Errored"
                Value       = 0
            }
        }

        $Jobs = foreach ($k in $Batches.Keys) {
            $Changes = 0
            [void]$BatchSB.Clear()
            foreach ($c in $Batches[$k]) {
                [void]$BatchSB.AppendLine('try {')
                [void]$BatchSB.AppendLine('    $i = 0')
                if ($c -is [Collections.Generic.Queue[object]]) {
                    while ($c.Count -gt 0) {
                        $Changes++
                        $CommandStatus.Pending.Value++
                        AddCommandToSB -BatchSB $BatchSB -Changes $Changes -Command ($c.Dequeue()) -TabCount 1
                    }
                }
                else {
                    $Changes++
                    $CommandStatus.Pending.Value++
                    AddCommandToSB -BatchSB $BatchSB -Changes $Changes -Command $c -TabCount 1
                }
                [void]$BatchSB.AppendLine('}')
                [void]$BatchSB.AppendLine('catch {')
                [void]$BatchSB.AppendLine('    Write-Warning "Command failure: $RunningCommand"')
                [void]$BatchSB.AppendLine('    Write-Warning "$($_.Exception.Message)"')
                [void]$BatchSB.AppendFormat('    if ({0} -gt $i) {{', $Changes)
                [void]$BatchSB.AppendLine()
                [void]$BatchSB.AppendFormat('        Write-Warning "$(({0} - $i) - 1) other changes skipped!"', $Changes)
                [void]$BatchSB.AppendLine()
                [void]$BatchSB.AppendFormat('        $_sync.CommandStatus.Skipped.Value += (({0} - $i) - 1)', $Changes)
                [void]$BatchSB.AppendLine()
                [void]$BatchSB.AppendFormat('        $_sync.CommandStatus.Completed.Value += ({0} - $i)', $Changes)
                [void]$BatchSB.AppendLine()
                [void]$BatchSB.AppendFormat('        $_sync.CommandStatus.Pending.Value -= ({0} - $i)', $Changes)
                [void]$BatchSB.AppendLine()
                [void]$BatchSB.AppendLine('    }')
                [void]$BatchSB.AppendLine('    else {')
                [void]$BatchSB.AppendLine('        $_sync.CommandStatus.Completed.Value++')
                [void]$BatchSB.AppendLine('        $_sync.CommandStatus.Pending.Value--')
                [void]$BatchSB.AppendLine('    }')
                [void]$BatchSB.AppendLine('    $_sync.CommandStatus.Errored.Value++')
                [void]$BatchSB.AppendLine('}')
                [void]$BatchSB.AppendLine()
            }
            if ($Changes -gt 0) {
                Write-Host "Starting job for Batch $k with $Changes changes"

                [PSCustomObject]@{
                    Id     = $k
                    Script = $BatchSB.ToString()
                }
            }
        }

        Invoke-ThreadedTeamsJob -Batches $Jobs -MaximumThreads $Jobs.Count -UpdateInterval $UpdateFrequency -CommandStatus $CommandStatus
    }
}
function AddCommandToSB {
    param (
        [Text.StringBuilder]
        $BatchSB,

        [int]
        $Changes,

        [string]
        $Command,

        [int]
        $TabCount = 1
    )
    end {
        $Prepend = [string]::new(' ', ($TabCount * 4))
        [void]$BatchSB.AppendFormat('{0}$i = {1}', $Prepend, $Changes)
        [void]$BatchSB.AppendLine()
        [void]$BatchSB.AppendFormat('{0}$RunningCommand = "{1}"', $Prepend, ($Command -replace '(?<!'')(?=["$])', '`'))
        [void]$BatchSB.AppendLine()
        [void]$BatchSB.AppendFormat('{0}{1}', $Prepend, $Command)
        [void]$BatchSB.AppendLine()
        if ($Command.StartsWith('$')) {
            # how should I handle variable replacements for dependencies?
        }
        [void]$BatchSB.AppendFormat('{0}$_sync.CommandStatus.Pending.Value--', $Prepend)
        [void]$BatchSB.AppendLine()
        [void]$BatchSB.AppendFormat('{0}$_sync.CommandStatus.Completed.Value++', $Prepend)
        [void]$BatchSB.AppendLine()
    }
}