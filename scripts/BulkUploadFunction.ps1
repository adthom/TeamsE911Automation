function Invoke-CsE911BulkOnlineChange {
    param (
        $Changes,

        [PSCredential]
        $Credential,

        [int]
        $MaxJobs = 30
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
        $GroupSize = [Math]::Floor($Sum / $GroupCount)
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

        $JobsStart = [DateTime]::Now()

        function getcurrent {
            [PSCustomObject][ordered]@{
                Addresses = Get-CsOnlineLisCivicAddress | Measure-Object | Select-Object -ExpandProperty Count
                Locations = Get-CsOnlineLisLocation | Measure-Object | Select-Object -ExpandProperty Count
                WAPs = Get-CsOnlineLisWirelessAccessPoint | Measure-Object | Select-Object -ExpandProperty Count
                Subnets = Get-CsOnlineLisSubnet | Measure-Object | Select-Object -ExpandProperty Count
                Switches = Get-CsOnlineLisSwitch | Measure-Object | Select-Object -ExpandProperty Count
                Ports = Get-CsOnlineLisPort | Measure-Object | Select-Object -ExpandProperty Count
                Elapsed = [DateTime]::Now - $JobsStart
            }
        }
        $currentStatus = getcurrent
        $Jobs = foreach ($k in $Batches.Keys) {
            $BatchSB = [Text.StringBuilder]::new()
            [void]$BatchSB.AppendFormat('# script for batch {0}', $k)
            [void]$BatchSB.AppendLine()
            [void]$BatchSB.AppendLine('param (')
            [void]$BatchSB.AppendLine('    [PSCredential] $Credential')
            [void]$BatchSB.AppendLine(')')
            [void]$BatchSB.AppendLine()
            [void]$BatchSB.AppendLine('# connect to Teams')
            [void]$BatchSB.AppendLine('Import-Module MicrosoftTeams')
            [void]$BatchSB.AppendLine('Connect-MicrosoftTeams -Credential $Credential -ErrorAction Stop | Out-Null')
            [void]$BatchSB.AppendLine()
            foreach ($q in $Batches[$k]) {
                [void]$BatchSB.AppendLine('try {')
                while ($q.Count -gt 0) {
                    [void]$BatchSB.AppendFormat('    {0}', $q.Dequeue())
                    [void]$BatchSB.AppendLine()
                }
                [void]$BatchSB.AppendLine('}')
                [void]$BatchSB.AppendLine('catch {')
                [void]$BatchSB.AppendLine('    Write-Warning $_.Exception.Message')
                [void]$BatchSB.AppendLine('}')
                [void]$BatchSB.AppendLine()
            }
            [void]$BatchSB.AppendLine()
            [void]$BatchSB.AppendLine('# disconnect from Teams')
            [void]$BatchSB.AppendLine('Disconnect-MicrosoftTeams -ErrorAction Stop | Out-Null')

            Start-Job -ScriptBlock ([ScriptBlock]::Create($BatchSB.ToString())) -Name "Batch $k" -ArgumentList $Credential
        }

        while ($Jobs.Count -gt 0) {
            $Done = @($Jobs | Wait-Job -Any -Timeout 120)
            $Done | Receive-Job -ErrorAction SilentlyContinue
            $Done | Remove-Job -ErrorAction SilentlyContinue
            $newStatus = getcurrent
            $es = $newStatus.Elapsed.TotalSeconds - $currentStatus.Elapsed.TotalSeconds
            if (($addresses = $newStatus.Addresses - $currentStatus.Addresses) -gt 0) {
                Write-Host "$addresses Addresses added ($([Math]::Round($addresses/$es,2))/s)"
            }
            if (($Locations = $newStatus.Locations - $currentStatus.Locations) -gt 0) {
                Write-Host "$Locations Locations added ($([Math]::Round($Locations/$es,2))/s)"
            }
            if (($WAPs = $newStatus.WAPs - $currentStatus.WAPs) -gt 0) {
                Write-Host "$WAPs WAPs added ($([Math]::Round($WAPs/$es,2))/s)"
            }
            if (($Subnets = $newStatus.Subnets - $currentStatus.Subnets) -gt 0) {
                Write-Host "$Subnets Subnets added ($([Math]::Round($Subnets/$es,2))/s)"
            }
            if (($Ports = $newStatus.Ports - $currentStatus.Ports) -gt 0) {
                Write-Host "$Ports Addresses added ($([Math]::Round($Ports/$es,2))/s)"
            }
            $currentStatus = $newStatus
            $Jobs = $Jobs | Where-Object { $_ -notin $Done }
        }
    }
}
