#Requires -Version 5.1
#Requires -Modules @{ModuleName='MicrosoftTeams'; ModuleVersion='4.2.0'}

function Remove-CsOnlineLisPortParallel {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [string]
        ${ChassisID},

        [Parameter(Mandatory = $true, Position = 1, ValueFromPipelineByPropertyName = $true)]
        [string]
        ${PortID},

        [switch]
        ${Force}
    )
    begin {
        $SW = [Diagnostics.StopWatch]::StartNew()
        $Command = Get-Command -Name 'Remove-CsOnlineLisPort'
        $CommonParametersToRemove = [Collections.Generic.List[string]]::new() 
        $CommonParametersToRemove.AddRange([string[]]@("InformationVariable", "WarningVariable", "ErrorVariable"))
        $i = 0
        $pool = [Microsoft.Teams.ConfigApi.Cmdlets.CustomRunspacePool]::new($Command)
        $pool.Begin()
    }

    process {
        $i++
        $D = [Collections.Generic.Dictionary[string, object]]::new()
        $Keys = $PSBoundParameters.Keys
        foreach ($K in $Keys) {
            if ([string]::IsNullOrEmpty($K) -or ([string]::IsNullOrEmpty($PSItem.$K))) {
                continue
            }
            if ($K -in $CommonParametersToRemove) {
                continue
            }
            $D.Add($K, $PSItem.$K)
        }
        $DefaultAutoRestParams = [Microsoft.Teams.ConfigApi.Cmdlets.FlightingUtils]::GetFlightingCommandInfo($D, $Command.Name, 'Modern').DefaultAutoRestParameters
        foreach ($parameter in $DefaultAutoRestParams) {
            if ([string]::IsNullOrEmpty($parameter.Key) -or [string]::IsNullOrEmpty($parameter.Value)) {
                continue
            }
            $D.Add($parameter.Key, $parameter.Value)
        }
        Write-Verbose "[$i] ($($SW.Elapsed.TotalSeconds.ToString('F0')))s $($Command.Name)$($D.Keys.ForEach({" -${_}$(if(![string]::IsNullOrEmpty($D[$_])){" '$($D[$_])'"})"}) -join '')"
        $pool.SendInput($D)
        $r = $pool.ReceiveOutput()
        $pendingResults, $errorsRec, $warnings = $r.Item1, $r.Item2, $r.Item3
        foreach ($warning in $warnings) {
            Write-Warning $warning.Message
        }
        foreach ($e in $errorsRec) {
            Write-Error $e
        }
        Write-Output $pendingResults
    }

    end {
        Write-Verbose "[$i] ($($SW.Elapsed.TotalSeconds.ToString('F0')))s Waiting for completion ($([DateTime]::Now.ToString('HH:mm:ss')))"
        $r = $pool.WaitForAndCollectRemainingOutput()
        $results, $errorsRec, $warnings = $r.Item1, $r.Item2, $r.Item3
        foreach ($warning in $warnings) {
            Write-Warning $warning.Message
        }
        foreach ($e in $errorsRec) {
            Write-Error $e
        }
        foreach ($result in $results) {
            Write-Output $result
        }
        $SW.Stop()
        Write-Verbose "[$i] ($($SW.Elapsed.TotalSeconds.ToString('F0')))s end"
    }
}

function Remove-CsOnlineLisWirelessAccessPointParallel {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [string]
        ${BSSID},

        [switch]
        ${Force}
    )

    begin {
        $SW = [Diagnostics.StopWatch]::StartNew()
        $Command = Get-Command -Name 'Remove-CsOnlineLisWirelessAccessPoint'
        $CommonParametersToRemove = [Collections.Generic.List[string]]::new()
        $CommonParametersToRemove.AddRange([string[]]@("InformationVariable", "WarningVariable", "ErrorVariable"))
        $i = 0
        $pool = [Microsoft.Teams.ConfigApi.Cmdlets.CustomRunspacePool]::new($Command)
        $pool.Begin()
    }

    process {
        $i++
        $D = [Collections.Generic.Dictionary[string, object]]::new()
        $Keys = $PSBoundParameters.Keys
        foreach ($K in $Keys) {
            if ([string]::IsNullOrEmpty($K) -or ([string]::IsNullOrEmpty($PSItem.$K))) {
                continue
            }
            if ($K -in $CommonParametersToRemove) {
                continue
            }
            $D.Add($K, $PSItem.$K)
        }
        $DefaultAutoRestParams = [Microsoft.Teams.ConfigApi.Cmdlets.FlightingUtils]::GetFlightingCommandInfo($D, $Command.Name, 'Modern').DefaultAutoRestParameters
        foreach ($parameter in $DefaultAutoRestParams) {
            if ([string]::IsNullOrEmpty($parameter.Key) -or [string]::IsNullOrEmpty($parameter.Value)) {
                continue
            }
            $D.Add($parameter.Key, $parameter.Value)
        }
        Write-Verbose "[$i] ($($SW.Elapsed.TotalSeconds.ToString('F0')))s $($Command.Name)$($D.Keys.ForEach({" -${_}$(if(![string]::IsNullOrEmpty($D[$_])){" '$($D[$_])'"})"}) -join '')"
        $pool.SendInput($D)
        $r = $pool.ReceiveOutput()
        $pendingResults, $errorsRec, $warnings = $r.Item1, $r.Item2, $r.Item3
        foreach ($warning in $warnings) {
            Write-Warning $warning.Message
        }
        foreach ($e in $errorsRec) {
            Write-Error $e
        }
        Write-Output $pendingResults
    }

    end {
        Write-Verbose "[$i] ($($SW.Elapsed.TotalSeconds.ToString('F0')))s Waiting for completion ($([DateTime]::Now.ToString('HH:mm:ss')))"
        $r = $pool.WaitForAndCollectRemainingOutput()
        $results, $errorsRec, $warnings = $r.Item1, $r.Item2, $r.Item3
        foreach ($warning in $warnings) {
            Write-Warning $warning.Message
        }
        foreach ($e in $errorsRec) {
            Write-Error $e
        }
        foreach ($result in $results) {
            Write-Output $result
        }
        $SW.Stop()
        Write-Verbose "[$i] ($($SW.Elapsed.TotalSeconds.ToString('F0')))s end"
    }
}

function Remove-CsOnlineLisSubnetParallel {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [string]
        ${Subnet},

        [switch]
        ${Force}
    )

    begin {
        $SW = [Diagnostics.StopWatch]::StartNew()
        $Command = Get-Command -Name 'Remove-CsOnlineLisSubnet'
        $CommonParametersToRemove = [Collections.Generic.List[string]]::new()
        $CommonParametersToRemove.AddRange([string[]]@("InformationVariable", "WarningVariable", "ErrorVariable"))
        $i = 0
        $pool = [Microsoft.Teams.ConfigApi.Cmdlets.CustomRunspacePool]::new($Command)
        $pool.Begin()
    }

    process {
        $i++
        $D = [Collections.Generic.Dictionary[string, object]]::new()
        $Keys = $PSBoundParameters.Keys
        foreach ($K in $Keys) {
            if ([string]::IsNullOrEmpty($K) -or ([string]::IsNullOrEmpty($PSItem.$K))) {
                continue
            }
            if ($K -in $CommonParametersToRemove) {
                continue
            }
            $D.Add($K, $PSItem.$K)
        }
        $DefaultAutoRestParams = [Microsoft.Teams.ConfigApi.Cmdlets.FlightingUtils]::GetFlightingCommandInfo($D, $Command.Name, 'Modern').DefaultAutoRestParameters
        foreach ($parameter in $DefaultAutoRestParams) {
            if ([string]::IsNullOrEmpty($parameter.Key) -or [string]::IsNullOrEmpty($parameter.Value)) {
                continue
            }
            $D.Add($parameter.Key, $parameter.Value)
        }
        Write-Verbose "[$i] ($($SW.Elapsed.TotalSeconds.ToString('F0')))s $($Command.Name)$($D.Keys.ForEach({" -${_}$(if(![string]::IsNullOrEmpty($D[$_])){" '$($D[$_])'"})"}) -join '')"
        $pool.SendInput($D)
        $r = $pool.ReceiveOutput()
        $pendingResults, $errorsRec, $warnings = $r.Item1, $r.Item2, $r.Item3
        foreach ($warning in $warnings) {
            Write-Warning $warning.Message
        }
        foreach ($e in $errorsRec) {
            Write-Error $e
        }
        Write-Output $pendingResults
    }

    end {
        Write-Verbose "[$i] ($($SW.Elapsed.TotalSeconds.ToString('F0')))s Waiting for completion ($([DateTime]::Now.ToString('HH:mm:ss')))"
        $r = $pool.WaitForAndCollectRemainingOutput()
        $results, $errorsRec, $warnings = $r.Item1, $r.Item2, $r.Item3
        foreach ($warning in $warnings) {
            Write-Warning $warning.Message
        }
        foreach ($e in $errorsRec) {
            Write-Error $e
        }
        foreach ($result in $results) {
            Write-Output $result
        }
        $SW.Stop()
        Write-Verbose "[$i] ($($SW.Elapsed.TotalSeconds.ToString('F0')))s end"
    }
}

function Remove-CsOnlineLisSwitchParallel {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [string]
        ${ChassisID},

        [switch]
        ${Force}
    )

    begin {
        $SW = [Diagnostics.StopWatch]::StartNew()
        $Command = Get-Command -Name 'Remove-CsOnlineLisSwitch'
        $CommonParametersToRemove = [Collections.Generic.List[string]]::new()
        $CommonParametersToRemove.AddRange([string[]]@("InformationVariable", "WarningVariable", "ErrorVariable"))
        $i = 0
        $pool = [Microsoft.Teams.ConfigApi.Cmdlets.CustomRunspacePool]::new($Command)
        $pool.Begin()
    }

    process {
        $i++
        $D = [Collections.Generic.Dictionary[string, object]]::new()
        $Keys = $PSBoundParameters.Keys
        foreach ($K in $Keys) {
            if ([string]::IsNullOrEmpty($K) -or ([string]::IsNullOrEmpty($PSItem.$K))) {
                continue
            }
            if ($K -in $CommonParametersToRemove) {
                continue
            }
            $D.Add($K, $PSItem.$K)
        }
        $DefaultAutoRestParams = [Microsoft.Teams.ConfigApi.Cmdlets.FlightingUtils]::GetFlightingCommandInfo($D, $Command.Name, 'Modern').DefaultAutoRestParameters
        foreach ($parameter in $DefaultAutoRestParams) {
            if ([string]::IsNullOrEmpty($parameter.Key) -or [string]::IsNullOrEmpty($parameter.Value)) {
                continue
            }
            $D.Add($parameter.Key, $parameter.Value)
        }
        Write-Verbose "[$i] ($($SW.Elapsed.TotalSeconds.ToString('F0')))s $($Command.Name)$($D.Keys.ForEach({" -${_}$(if(![string]::IsNullOrEmpty($D[$_])){" '$($D[$_])'"})"}) -join '')"
        $pool.SendInput($D)
        $r = $pool.ReceiveOutput()
        $pendingResults, $errorsRec, $warnings = $r.Item1, $r.Item2, $r.Item3
        foreach ($warning in $warnings) {
            Write-Warning $warning.Message
        }
        foreach ($e in $errorsRec) {
            Write-Error $e
        }
        Write-Output $pendingResults
    }

    end {
        Write-Verbose "[$i] ($($SW.Elapsed.TotalSeconds.ToString('F0')))s Waiting for completion ($([DateTime]::Now.ToString('HH:mm:ss')))"
        $r = $pool.WaitForAndCollectRemainingOutput()
        $results, $errorsRec, $warnings = $r.Item1, $r.Item2, $r.Item3
        foreach ($warning in $warnings) {
            Write-Warning $warning.Message
        }
        foreach ($e in $errorsRec) {
            Write-Error $e
        }
        foreach ($result in $results) {
            Write-Output $result
        }
        $SW.Stop()
        Write-Verbose "[$i] ($($SW.Elapsed.TotalSeconds.ToString('F0')))s end"
    }
}

function Remove-CsOnlineLisLocationParallel {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNull()]
        [guid]
        ${LocationId},

        [switch]
        ${Force}
    )

    begin {
        $SW = [Diagnostics.StopWatch]::StartNew()
        $Command = Get-Command -Name 'Remove-CsOnlineLisLocation'
        $CommonParametersToRemove = [Collections.Generic.List[string]]::new()
        $CommonParametersToRemove.AddRange([string[]]@("InformationVariable", "WarningVariable", "ErrorVariable"))
        $i = 0
        $pool = [Microsoft.Teams.ConfigApi.Cmdlets.CustomRunspacePool]::new($Command)
        $pool.Begin()
    }

    process {
        $i++
        $D = [Collections.Generic.Dictionary[string, object]]::new()
        $Keys = $PSBoundParameters.Keys
        foreach ($K in $Keys) {
            if ([string]::IsNullOrEmpty($K) -or ([string]::IsNullOrEmpty($PSItem.$K))) {
                continue
            }
            if ($K -in $CommonParametersToRemove) {
                continue
            }
            $D.Add($K, $PSItem.$K)
        }
        $DefaultAutoRestParams = [Microsoft.Teams.ConfigApi.Cmdlets.FlightingUtils]::GetFlightingCommandInfo($D, $Command.Name, 'Modern').DefaultAutoRestParameters
        foreach ($parameter in $DefaultAutoRestParams) {
            if ([string]::IsNullOrEmpty($parameter.Key) -or [string]::IsNullOrEmpty($parameter.Value)) {
                continue
            }
            $D.Add($parameter.Key, $parameter.Value)
        }
        Write-Verbose "[$i] ($($SW.Elapsed.TotalSeconds.ToString('F0')))s $($Command.Name)$($D.Keys.ForEach({" -${_}$(if(![string]::IsNullOrEmpty($D[$_])){" '$($D[$_])'"})"}) -join '')"
        $pool.SendInput($D)
        $r = $pool.ReceiveOutput()
        $pendingResults, $errorsRec, $warnings = $r.Item1, $r.Item2, $r.Item3
        foreach ($warning in $warnings) {
            Write-Warning $warning.Message
        }
        foreach ($e in $errorsRec) {
            Write-Error $e
        }
        Write-Output $pendingResults
    }

    end {
        Write-Verbose "[$i] ($($SW.Elapsed.TotalSeconds.ToString('F0')))s Waiting for completion ($([DateTime]::Now.ToString('HH:mm:ss')))"
        $r = $pool.WaitForAndCollectRemainingOutput()
        $results, $errorsRec, $warnings = $r.Item1, $r.Item2, $r.Item3
        foreach ($warning in $warnings) {
            Write-Warning $warning.Message
        }
        foreach ($e in $errorsRec) {
            Write-Error $e
        }
        foreach ($result in $results) {
            Write-Output $result
        }
        $SW.Stop()
        Write-Verbose "[$i] ($($SW.Elapsed.TotalSeconds.ToString('F0')))s end"
    }
}

function Remove-CsOnlineLisCivicAddressParallel {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNull()]
        [guid]
        ${CivicAddressId},

        [switch]
        ${Force}
    )
    begin {
        $SW = [Diagnostics.StopWatch]::StartNew()
        $Command = Get-Command -Name 'Remove-CsOnlineLisCivicAddress'
        $CommonParametersToRemove = [Collections.Generic.List[string]]::new()
        $CommonParametersToRemove.AddRange([string[]]@("InformationVariable", "WarningVariable", "ErrorVariable"))
        $i = 0
        $pool = [Microsoft.Teams.ConfigApi.Cmdlets.CustomRunspacePool]::new($Command)
        $pool.Begin()
    }

    process {
        $i++
        $D = [Collections.Generic.Dictionary[string, object]]::new()
        $Keys = $PSBoundParameters.Keys
        foreach ($K in $Keys) {
            if ([string]::IsNullOrEmpty($K) -or ([string]::IsNullOrEmpty($PSItem.$K))) {
                continue
            }
            if ($K -in $CommonParametersToRemove) {
                continue
            }
            $D.Add($K, $PSItem.$K)
        }
        $DefaultAutoRestParams = [Microsoft.Teams.ConfigApi.Cmdlets.FlightingUtils]::GetFlightingCommandInfo($D, $Command.Name, 'Modern').DefaultAutoRestParameters
        foreach ($parameter in $DefaultAutoRestParams) {
            if ([string]::IsNullOrEmpty($parameter.Key) -or [string]::IsNullOrEmpty($parameter.Value)) {
                continue
            }
            $D.Add($parameter.Key, $parameter.Value)
        }
        Write-Verbose "[$i] ($($SW.Elapsed.TotalSeconds.ToString('F0')))s $($Command.Name)$($D.Keys.ForEach({" -${_}$(if(![string]::IsNullOrEmpty($D[$_])){" '$($D[$_])'"})"}) -join '')"
        $pool.SendInput($D)
        $r = $pool.ReceiveOutput()
        $pendingResults, $errorsRec, $warnings = $r.Item1, $r.Item2, $r.Item3
        foreach ($warning in $warnings) {
            Write-Warning $warning.Message
        }
        foreach ($e in $errorsRec) {
            Write-Error $e
        }
        Write-Output $pendingResults
    }

    end {
        Write-Verbose "[$i] ($($SW.Elapsed.TotalSeconds.ToString('F0')))s Waiting for completion ($([DateTime]::Now.ToString('HH:mm:ss')))"
        $r = $pool.WaitForAndCollectRemainingOutput()
        $results, $errorsRec, $warnings = $r.Item1, $r.Item2, $r.Item3
        foreach ($warning in $warnings) {
            Write-Warning $warning.Message
        }
        foreach ($e in $errorsRec) {
            Write-Error $e
        }
        foreach ($result in $results) {
            Write-Output $result
        }
        $SW.Stop()
        Write-Verbose "[$i] ($($SW.Elapsed.TotalSeconds.ToString('F0')))s end"
    }
}

function Set-CsOnlineLisPortParallel {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [guid]
        ${LocationId},

        [Parameter(Mandatory = $true, Position = 1, ValueFromPipelineByPropertyName = $true)]
        [string]
        ${ChassisID},
    
        [Parameter(Mandatory = $true, Position = 2, ValueFromPipelineByPropertyName = $true)]
        [string]
        ${PortID},

        [Parameter(Position = 3, ValueFromPipelineByPropertyName = $true)]
        [string]
        ${Description},
    
        [switch]
        ${Force}
    )
    
    begin {
        $SW = [Diagnostics.StopWatch]::StartNew()
        $Command = Get-Command -Name 'Set-CsOnlineLisPort'
        $CommonParametersToRemove = [Collections.Generic.List[string]]::new()
        $CommonParametersToRemove.AddRange([string[]]@("InformationVariable", "WarningVariable", "ErrorVariable"))
        $i = 0
        $pool = [Microsoft.Teams.ConfigApi.Cmdlets.CustomRunspacePool]::new($Command)
        $pool.Begin()
    }

    process {
        $i++
        $D = [Collections.Generic.Dictionary[string, object]]::new()
        $Keys = $PSBoundParameters.Keys
        foreach ($K in $Keys) {
            if ([string]::IsNullOrEmpty($K) -or ([string]::IsNullOrEmpty($PSItem.$K))) {
                continue
            }
            if ($K -in $CommonParametersToRemove) {
                continue
            }
            $D.Add($K, $PSItem.$K)
        }
        $DefaultAutoRestParams = [Microsoft.Teams.ConfigApi.Cmdlets.FlightingUtils]::GetFlightingCommandInfo($D, $Command.Name, 'Modern').DefaultAutoRestParameters
        foreach ($parameter in $DefaultAutoRestParams) {
            if ([string]::IsNullOrEmpty($parameter.Key) -or [string]::IsNullOrEmpty($parameter.Value)) {
                continue
            }
            $D.Add($parameter.Key, $parameter.Value)
        }
        Write-Verbose "[$i] ($($SW.Elapsed.TotalSeconds.ToString('F0')))s $($Command.Name)$($D.Keys.ForEach({" -${_}$(if(![string]::IsNullOrEmpty($D[$_])){" '$($D[$_])'"})"}) -join '')"
        $pool.SendInput($D)
        $r = $pool.ReceiveOutput()
        $pendingResults, $errorsRec, $warnings = $r.Item1, $r.Item2, $r.Item3
        foreach ($warning in $warnings) {
            Write-Warning $warning.Message
        }
        foreach ($e in $errorsRec) {
            Write-Error $e
        }
        Write-Output $pendingResults
    }

    end {
        Write-Verbose "[$i] ($($SW.Elapsed.TotalSeconds.ToString('F0')))s Waiting for completion ($([DateTime]::Now.ToString('HH:mm:ss')))"
        $r = $pool.WaitForAndCollectRemainingOutput()
        $results, $errorsRec, $warnings = $r.Item1, $r.Item2, $r.Item3
        foreach ($warning in $warnings) {
            Write-Warning $warning.Message
        }
        foreach ($e in $errorsRec) {
            Write-Error $e
        }
        foreach ($result in $results) {
            Write-Output $result
        }
        $SW.Stop()
        Write-Verbose "[$i] ($($SW.Elapsed.TotalSeconds.ToString('F0')))s end"
    }
}

function Set-CsOnlineLisSwitchParallel {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [guid]
        ${LocationId},

        [Parameter(Mandatory = $true, Position = 1, ValueFromPipelineByPropertyName = $true)]
        [string]
        ${ChassisID},

        [Parameter(Position = 2, ValueFromPipelineByPropertyName = $true)]
        [string]
        ${Description},
    
        [switch]
        ${Force}
    )
    
    begin {
        $SW = [Diagnostics.StopWatch]::StartNew()
        $Command = Get-Command -Name 'Set-CsOnlineLisSwitch'
        $CommonParametersToRemove = [Collections.Generic.List[string]]::new()
        $CommonParametersToRemove.AddRange([string[]]@("InformationVariable", "WarningVariable", "ErrorVariable"))
        $i = 0
        $pool = [Microsoft.Teams.ConfigApi.Cmdlets.CustomRunspacePool]::new($Command)
        $pool.Begin()
    }

    process {
        $i++
        $D = [Collections.Generic.Dictionary[string, object]]::new()
        $Keys = $PSBoundParameters.Keys
        foreach ($K in $Keys) {
            if ([string]::IsNullOrEmpty($K) -or ([string]::IsNullOrEmpty($PSItem.$K))) {
                continue
            }
            if ($K -in $CommonParametersToRemove) {
                continue
            }
            $D.Add($K, $PSItem.$K)
        }
        $DefaultAutoRestParams = [Microsoft.Teams.ConfigApi.Cmdlets.FlightingUtils]::GetFlightingCommandInfo($D, $Command.Name, 'Modern').DefaultAutoRestParameters
        foreach ($parameter in $DefaultAutoRestParams) {
            if ([string]::IsNullOrEmpty($parameter.Key) -or [string]::IsNullOrEmpty($parameter.Value)) {
                continue
            }
            $D.Add($parameter.Key, $parameter.Value)
        }
        Write-Verbose "[$i] ($($SW.Elapsed.TotalSeconds.ToString('F0')))s $($Command.Name)$($D.Keys.ForEach({" -${_}$(if(![string]::IsNullOrEmpty($D[$_])){" '$($D[$_])'"})"}) -join '')"
        $pool.SendInput($D)
        $r = $pool.ReceiveOutput()
        $pendingResults, $errorsRec, $warnings = $r.Item1, $r.Item2, $r.Item3
        foreach ($warning in $warnings) {
            Write-Warning $warning.Message
        }
        foreach ($e in $errorsRec) {
            Write-Error $e
        }
        Write-Output $pendingResults
    }

    end {
        Write-Verbose "[$i] ($($SW.Elapsed.TotalSeconds.ToString('F0')))s Waiting for completion ($([DateTime]::Now.ToString('HH:mm:ss')))"
        $r = $pool.WaitForAndCollectRemainingOutput()
        $results, $errorsRec, $warnings = $r.Item1, $r.Item2, $r.Item3
        foreach ($warning in $warnings) {
            Write-Warning $warning.Message
        }
        foreach ($e in $errorsRec) {
            Write-Error $e
        }
        foreach ($result in $results) {
            Write-Output $result
        }
        $SW.Stop()
        Write-Verbose "[$i] ($($SW.Elapsed.TotalSeconds.ToString('F0')))s end"
    }
}

function Set-CsOnlineLisSubnetParallel {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [guid]
        ${LocationId},

        [Parameter(Mandatory = $true, Position = 1, ValueFromPipelineByPropertyName = $true)]
        [string]
        ${Subnet},

        [Parameter(Position = 2, ValueFromPipelineByPropertyName = $true)]
        [string]
        ${Description},
    
        [switch]
        ${Force}
    )
    
    begin {
        $SW = [Diagnostics.StopWatch]::StartNew()
        $Command = Get-Command -Name 'Set-CsOnlineLisSubnet'
        $CommonParametersToRemove = [Collections.Generic.List[string]]::new()
        $CommonParametersToRemove.AddRange([string[]]@("InformationVariable", "WarningVariable", "ErrorVariable"))
        $i = 0
        $pool = [Microsoft.Teams.ConfigApi.Cmdlets.CustomRunspacePool]::new($Command)
        $pool.Begin()
    }

    process {
        $i++
        $D = [Collections.Generic.Dictionary[string, object]]::new()
        $Keys = $PSBoundParameters.Keys
        foreach ($K in $Keys) {
            if ([string]::IsNullOrEmpty($K) -or ([string]::IsNullOrEmpty($PSItem.$K))) {
                continue
            }
            if ($K -in $CommonParametersToRemove) {
                continue
            }
            $D.Add($K, $PSItem.$K)
        }
        $DefaultAutoRestParams = [Microsoft.Teams.ConfigApi.Cmdlets.FlightingUtils]::GetFlightingCommandInfo($D, $Command.Name, 'Modern').DefaultAutoRestParameters
        foreach ($parameter in $DefaultAutoRestParams) {
            if ([string]::IsNullOrEmpty($parameter.Key) -or [string]::IsNullOrEmpty($parameter.Value)) {
                continue
            }
            $D.Add($parameter.Key, $parameter.Value)
        }
        Write-Verbose "[$i] ($($SW.Elapsed.TotalSeconds.ToString('F0')))s $($Command.Name)$($D.Keys.ForEach({" -${_}$(if(![string]::IsNullOrEmpty($D[$_])){" '$($D[$_])'"})"}) -join '')"
        $pool.SendInput($D)
        $r = $pool.ReceiveOutput()
        $pendingResults, $errorsRec, $warnings = $r.Item1, $r.Item2, $r.Item3
        foreach ($warning in $warnings) {
            Write-Warning $warning.Message
        }
        foreach ($e in $errorsRec) {
            Write-Error $e
        }
        Write-Output $pendingResults
    }

    end {
        Write-Verbose "[$i] ($($SW.Elapsed.TotalSeconds.ToString('F0')))s Waiting for completion ($([DateTime]::Now.ToString('HH:mm:ss')))"
        $r = $pool.WaitForAndCollectRemainingOutput()
        $results, $errorsRec, $warnings = $r.Item1, $r.Item2, $r.Item3
        foreach ($warning in $warnings) {
            Write-Warning $warning.Message
        }
        foreach ($e in $errorsRec) {
            Write-Error $e
        }
        foreach ($result in $results) {
            Write-Output $result
        }
        $SW.Stop()
        Write-Verbose "[$i] ($($SW.Elapsed.TotalSeconds.ToString('F0')))s end"
    }
}

function Set-CsOnlineLisWirelessAccessPointParallel {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [guid]
        ${LocationId},

        [Parameter(Mandatory = $true, Position = 1, ValueFromPipelineByPropertyName = $true)]
        [string]
        ${BSSID},

        [Parameter(Position = 2, ValueFromPipelineByPropertyName = $true)]
        [string]
        ${Description},
    
        [switch]
        ${Force}
    )
    
    begin {
        $SW = [Diagnostics.StopWatch]::StartNew()
        $Command = Get-Command -Name 'Set-CsOnlineLisWirelessAccessPoint'
        $CommonParametersToRemove = [Collections.Generic.List[string]]::new()
        $CommonParametersToRemove.AddRange([string[]]@("InformationVariable", "WarningVariable", "ErrorVariable"))
        $i = 0
        $pool = [Microsoft.Teams.ConfigApi.Cmdlets.CustomRunspacePool]::new($Command)
        $pool.Begin()
    }

    process {
        $i++
        $D = [Collections.Generic.Dictionary[string, object]]::new()
        $Keys = $PSBoundParameters.Keys
        foreach ($K in $Keys) {
            if ([string]::IsNullOrEmpty($K) -or ([string]::IsNullOrEmpty($PSItem.$K))) {
                continue
            }
            if ($K -in $CommonParametersToRemove) {
                continue
            }
            $D.Add($K, $PSItem.$K)
        }
        $DefaultAutoRestParams = [Microsoft.Teams.ConfigApi.Cmdlets.FlightingUtils]::GetFlightingCommandInfo($D, $Command.Name, 'Modern').DefaultAutoRestParameters
        foreach ($parameter in $DefaultAutoRestParams) {
            if ([string]::IsNullOrEmpty($parameter.Key) -or [string]::IsNullOrEmpty($parameter.Value)) {
                continue
            }
            $D.Add($parameter.Key, $parameter.Value)
        }
        Write-Verbose "[$i] ($($SW.Elapsed.TotalSeconds.ToString('F0')))s $($Command.Name)$($D.Keys.ForEach({" -${_}$(if(![string]::IsNullOrEmpty($D[$_])){" '$($D[$_])'"})"}) -join '')"
        $pool.SendInput($D)
        $r = $pool.ReceiveOutput()
        $pendingResults, $errorsRec, $warnings = $r.Item1, $r.Item2, $r.Item3
        foreach ($warning in $warnings) {
            Write-Warning $warning.Message
        }
        foreach ($e in $errorsRec) {
            Write-Error $e
        }
        Write-Output $pendingResults
    }

    end {
        Write-Verbose "[$i] ($($SW.Elapsed.TotalSeconds.ToString('F0')))s Waiting for completion ($([DateTime]::Now.ToString('HH:mm:ss')))"
        $r = $pool.WaitForAndCollectRemainingOutput()
        $results, $errorsRec, $warnings = $r.Item1, $r.Item2, $r.Item3
        foreach ($warning in $warnings) {
            Write-Warning $warning.Message
        }
        foreach ($e in $errorsRec) {
            Write-Error $e
        }
        foreach ($result in $results) {
            Write-Output $result
        }
        $SW.Stop()
        Write-Verbose "[$i] ($($SW.Elapsed.TotalSeconds.ToString('F0')))s end"
    }
}

function Remove-CsOnlineLisConfiguration {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [switch]
        ${Force}
    )
    begin {
        $SW = [Diagnostics.StopWatch]::StartNew()
        $NetworkObjectsRemaining = 0
        Write-Host "Getting Current Subnets: " -NoNewline
        $Subnets = @(Get-CsOnlineLisSubnet).Where({ $_.Subnet })
        Write-Host "Found $($Subnets.Count)"
        $NetworkObjectsRemaining += $Subnets.Count

        Write-Host "Getting Current Switches: " -NoNewline
        $Switches = @(Get-CsOnlineLisSwitch).Where({ $_.ChassisId })
        Write-Host "Found $($Switches.Count)"
        $NetworkObjectsRemaining += $Switches.Count
    
        Write-Host "Getting Current Ports: " -NoNewline
        $Ports = @(Get-CsOnlineLisPort).Where({ $_.ChassisId -and $_.PortId })
        Write-Host "Found $($Ports.Count)"
        $NetworkObjectsRemaining += $Ports.Count
        
        Write-Host "Getting Current Wireless Access Points: " -NoNewline
        $WirelessAccessPoints = @(Get-CsOnlineLisWirelessAccessPoint).Where({ $_.Bssid })
        Write-Host "Found $($WirelessAccessPoints.Count)"
        $NetworkObjectsRemaining += $WirelessAccessPoints.Count

        Write-Host "Getting Current Civic Addresses: " -NoNewline
        $Addresses = @(Get-CsOnlineLisCivicAddress -PopulateNumberOfVoiceUsers -PopulateNumberOfTelephoneNumbers)
        Write-Host "Found $($Addresses.Where({$_.NumberOfVoiceUsers -le 0 -and $_.NumberOfTelephoneNumbers -le 0}).Count)"

        Write-Host "Getting Current Locations: " -NoNewline
        $Locations = @(Get-CsOnlineLisLocation).Where({ $Location = $_; $addr = $Addresses.Where({ $_.CivicAddressId -eq $Location.CivicAddressId -and $Location.LocationId -ne $_.DefaultLocationId }); $null -ne $addr -and $addr.Count -gt 0 })
        Write-Host "Found $($Locations.Count)"

        Write-Host

        $TotalRemoved = 0
    }
    end {
        while ($NetworkObjectsRemaining -gt 0) {
            $NetworkObjectsRemaining = 0
            if ($Subnets.Count -gt 0) {
                $PreCount = $Subnets.Count
                Write-Host "Removing $($Subnets.Count) Subnets"
                $Subnets | Remove-CsOnlineLisSubnetParallel @PSBoundParameters
                Write-Host "Checking For Remaining Subnets... " -NoNewline
                $Subnets = @(Get-CsOnlineLisSubnet).Where({ $_.Subnet })
                if ($Subnets.Count -gt 0) {
                    Write-Host "Found $($Subnets.Count) Further processing required..."
                }
                Write-Host
                $NetworkObjectsRemaining += $Subnets.Count
                $TotalRemoved += ($PreCount - $Subnets.Count)
            }
            if ($Switches.Count -gt 0) {
                $PreCount = $Switches.Count
                Write-Host "Removing $($Switches.Count) Switches"
                $Switches | Remove-CsOnlineLisSwitchParallel @PSBoundParameters
                Write-Host "Checking For Remaining Switches... " -NoNewline
                $Switches = @(Get-CsOnlineLisSwitch).Where({ $_.ChassisId })
                if ($Switches.Count -gt 0) {
                    Write-Host "Found $($Switches.Count) Further processing required..."
                }
                Write-Host
                $NetworkObjectsRemaining += $Switches.Count
                $TotalRemoved += ($PreCount - $Switches.Count)
            }
            if ($Ports.Count -gt 0) {
                $PreCount = $Ports.Count
                Write-Host "Removing $($Ports.Count) Ports"
                $Ports | Remove-CsOnlineLisPortParallel @PSBoundParameters
                Write-Host "Checking For Remaining Ports... " -NoNewline
                $Ports = @(Get-CsOnlineLisPort).Where({ $_.ChassisId -and $_.PortId })
                if ($Ports.Count -gt 0) {
                    Write-Host "Found $($Ports.Count) Further processing required..."
                }
                Write-Host
                $NetworkObjectsRemaining += $Ports.Count
                $TotalRemoved += ($PreCount - $Ports.Count)
            }
            if ($WirelessAccessPoints.Count -gt 0) {
                $PreCount = $WirelessAccessPoints.Count
                Write-Host "Removing $($WirelessAccessPoints.Count) Wireless Access Points"
                $WirelessAccessPoints | Remove-CsOnlineLisWirelessAccessPointParallel @PSBoundParameters
                Write-Host "Checking For Remaining Wireless Access Points... " -NoNewline
                $WirelessAccessPoints = @(Get-CsOnlineLisWirelessAccessPoint).Where({ $_.Bssid })
                $NetworkObjectsRemaining += $WirelessAccessPoints.Count
                if ($WirelessAccessPoints.Count -gt 0) {
                    Write-Host "Found $($WirelessAccessPoints.Count) Further processing required..."
                }
                Write-Host
                $NetworkObjectsRemaining += $WirelessAccessPoints.Count
                $TotalRemoved += ($PreCount - $WirelessAccessPoints.Count)
            }
        }

        while ($Locations.Count -gt 0) {
            $PreCount = $Locations.Count
            Write-Host "Removing $($Locations.Count) Locations"
            $Locations | Remove-CsOnlineLisLocationParallel @PSBoundParameters
            Write-Host "Checking For Remaining Locations... " -NoNewline
            $Locations = @(Get-CsOnlineLisLocation).Where({ $Location = $_; $addr = $Addresses.Where({ $_.CivicAddressId -eq $Location.CivicAddressId -and $Location.LocationId -ne $_.DefaultLocationId }); $null -ne $addr -and $addr.Count -gt 0 })
            if ($Locations.Count -gt 0) {
                Write-Host "Found $($Locations.Count) Further processing required..."
            }
            Write-Host
            $TotalRemoved += ($PreCount - $Locations.Count)
        }

        # remove addresses which cannot be removed from our array to process
        $PreCount = $Addresses.Count
        $Addresses = $Addresses.Where({ $_.NumberOfVoiceUsers -le 0 -and $_.NumberOfTelephoneNumbers -le 0 })
        if ($PreCount -gt $Addresses.Count) {
            Write-Host "$($PreCount - $Addresses.Count) Civic Addresses have either Voice Users or Telephone Numbers assigned, they will be skipped..."
            Write-Host
        }
        while ($Addresses.Count -gt 0) {
            $PreCount = $Addresses.Count
            Write-Host "Removing $($Addresses.Count) Civic Addresses"
            $Addresses | Remove-CsOnlineLisCivicAddressParallel @PSBoundParameters
            Write-Host "Checking For Remaining Civic Addresses... " -NoNewline
            $Addresses = @(Get-CsOnlineLisCivicAddress -PopulateNumberOfVoiceUsers -PopulateNumberOfTelephoneNumbers).Where({ $_.NumberOfVoiceUsers -le 0 -and $_.NumberOfTelephoneNumbers -le 0 })
            if ($Addresses.Count -gt 0) {
                Write-Host "Found $($Addresses.Count) Further processing required..."
            }
            Write-Host
            $TotalRemoved += ($PreCount - $Addresses.Count)
        }

        $SW.Stop()
        Write-Host "Removed $($TotalRemoved) items in $($SW.Elapsed.TotalSeconds.ToString("F0"))s"
        Write-Host
    }
}
Export-ModuleMember -Function Remove-CsOnlineLisConfiguration


function New-CsOnlineLisCivicAddressParallel {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium', PositionalBinding=$false)]
    param(
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [string]
        ${CompanyName},
    
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [string]
        ${CountryOrRegion},
    
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [string]
        ${City},
    
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [string]
        ${CityAlias},
    
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [string]
        ${CompanyTaxId},
    
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [string]
        ${Confidence},
    
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [string]
        ${Description},
    
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [string]
        ${Elin},
    
        [switch]
        ${Force},
    
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [string]
        ${HouseNumber},
    
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [string]
        ${HouseNumberSuffix},
    
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [bool]
        ${IsAzureMapValidationRequired},
    
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [string]
        ${Latitude},
    
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [string]
        ${Longitude},
    
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [string]
        ${PostalCode},
    
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [string]
        ${PostDirectional},
    
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [string]
        ${PreDirectional},
    
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [string]
        ${StateOrProvince},
    
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [string]
        ${StreetName},
    
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [string]
        ${StreetSuffix},
    
        [string]
        ${ValidationStatus}
    )

    begin {
        $SW = [Diagnostics.StopWatch]::StartNew()
        $Command = Get-Command -Name 'New-CsOnlineLisCivicAddress'
        $CommonParametersToRemove = [Collections.Generic.List[string]]::new()
        $CommonParametersToRemove.AddRange([string[]]@("InformationVariable", "WarningVariable", "ErrorVariable"))
        $i = 0
        $pool = [Microsoft.Teams.ConfigApi.Cmdlets.CustomRunspacePool]::new($Command)
        $pool.Begin()
    }

    process {
        $i++
        $D = [Collections.Generic.Dictionary[string, object]]::new()
        $Keys = $PSBoundParameters.Keys
        foreach ($K in $Keys) {
            if ([string]::IsNullOrEmpty($K) -or ([string]::IsNullOrEmpty($PSItem.$K))) {
                continue
            }
            if ($K -in $CommonParametersToRemove) {
                continue
            }
            $D.Add($K, $PSItem.$K)
        }
        $DefaultAutoRestParams = [Microsoft.Teams.ConfigApi.Cmdlets.FlightingUtils]::GetFlightingCommandInfo($D, $Command.Name, 'Modern').DefaultAutoRestParameters
        foreach ($parameter in $DefaultAutoRestParams) {
            if ([string]::IsNullOrEmpty($parameter.Key) -or [string]::IsNullOrEmpty($parameter.Value)) {
                continue
            }
            $D.Add($parameter.Key, $parameter.Value)
        }
        Write-Verbose "[$i] ($($SW.Elapsed.TotalSeconds.ToString('F0')))s $($Command.Name)$($D.Keys.ForEach({" -${_}$(if(![string]::IsNullOrEmpty($D[$_])){" '$($D[$_])'"})"}) -join '')"
        $pool.SendInput($D)
        $r = $pool.ReceiveOutput()
        $pendingResults, $errorsRec, $warnings = $r.Item1, $r.Item2, $r.Item3
        foreach ($warning in $warnings) {
            Write-Warning $warning.Message
        }
        foreach ($e in $errorsRec) {
            Write-Error $e
        }
        Write-Output $pendingResults
    }

    end {
        Write-Verbose "[$i] ($($SW.Elapsed.TotalSeconds.ToString('F0')))s Waiting for completion ($([DateTime]::Now.ToString('HH:mm:ss')))"
        $r = $pool.WaitForAndCollectRemainingOutput()
        $results, $errorsRec, $warnings = $r.Item1, $r.Item2, $r.Item3
        foreach ($warning in $warnings) {
            Write-Warning $warning.Message
        }
        foreach ($e in $errorsRec) {
            Write-Error $e
        }
        foreach ($result in $results) {
            Write-Output $result
        }
        $SW.Stop()
        Write-Verbose "[$i] ($($SW.Elapsed.TotalSeconds.ToString('F0')))s end"
    }
}
Export-ModuleMember -Function New-CsOnlineLisCivicAddressParallel

function New-CsOnlineLisLocationParallel {
    [CmdletBinding(DefaultParameterSetName='ExistingCivicAddress', SupportsShouldProcess=$true, ConfirmImpact='Medium', PositionalBinding=$false)]
    param(
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [string]
        ${Location},
    
        [Parameter(ParameterSetName='ExistingCivicAddress', Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [guid]
        ${CivicAddressId},
    
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [string]
        ${CityAlias},
    
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [Alias('Name')]
        [string]
        ${CompanyName},
    
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [string]
        ${CompanyTaxId},
    
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [string]
        ${Confidence},
    
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [string]
        ${Elin},
    
        [switch]
        ${Force},
    
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [string]
        ${HouseNumberSuffix},
    
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [string]
        ${Latitude},
    
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [string]
        ${Longitude},
    
        [Parameter(ParameterSetName='CreateCivicAddress', Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [Alias('Country')]
        [string]
        ${CountryOrRegion},
    
        [Parameter(ParameterSetName='CreateCivicAddress', ValueFromPipelineByPropertyName=$true)]
        [string]
        ${City},
    
        [Parameter(ParameterSetName='CreateCivicAddress', ValueFromPipelineByPropertyName=$true)]
        [string]
        ${Description},
    
        [Parameter(ParameterSetName='CreateCivicAddress', ValueFromPipelineByPropertyName=$true)]
        [string]
        ${HouseNumber},
    
        [Parameter(ParameterSetName='CreateCivicAddress', ValueFromPipelineByPropertyName=$true)]
        [string]
        ${PostalCode},
    
        [Parameter(ParameterSetName='CreateCivicAddress', ValueFromPipelineByPropertyName=$true)]
        [string]
        ${PostDirectional},
    
        [Parameter(ParameterSetName='CreateCivicAddress', ValueFromPipelineByPropertyName=$true)]
        [string]
        ${PreDirectional},
    
        [Parameter(ParameterSetName='CreateCivicAddress', ValueFromPipelineByPropertyName=$true)]
        [Alias('State')]
        [string]
        ${StateOrProvince},
    
        [Parameter(ParameterSetName='CreateCivicAddress', ValueFromPipelineByPropertyName=$true)]
        [string]
        ${StreetName},
    
        [Parameter(ParameterSetName='CreateCivicAddress', ValueFromPipelineByPropertyName=$true)]
        [string]
        ${StreetSuffix}
    )

    begin {
        $SW = [Diagnostics.StopWatch]::StartNew()
        $Command = Get-Command -Name 'New-CsOnlineLisLocation'
        $CommonParametersToRemove = [Collections.Generic.List[string]]::new()
        $CommonParametersToRemove.AddRange([string[]]@("InformationVariable", "WarningVariable", "ErrorVariable"))
        $i = 0
        $pool = [Microsoft.Teams.ConfigApi.Cmdlets.CustomRunspacePool]::new($Command)
        $pool.Begin()
    }

    process {
        $i++
        $D = [Collections.Generic.Dictionary[string, object]]::new()
        $Keys = $PSBoundParameters.Keys
        foreach ($K in $Keys) {
            if ([string]::IsNullOrEmpty($K) -or ([string]::IsNullOrEmpty($PSItem.$K))) {
                continue
            }
            if ($K -in $CommonParametersToRemove) {
                continue
            }
            $D.Add($K, $PSItem.$K)
        }
        $DefaultAutoRestParams = [Microsoft.Teams.ConfigApi.Cmdlets.FlightingUtils]::GetFlightingCommandInfo($D, $Command.Name, 'Modern').DefaultAutoRestParameters
        foreach ($parameter in $DefaultAutoRestParams) {
            if ([string]::IsNullOrEmpty($parameter.Key) -or [string]::IsNullOrEmpty($parameter.Value)) {
                continue
            }
            $D.Add($parameter.Key, $parameter.Value)
        }
        Write-Verbose "[$i] ($($SW.Elapsed.TotalSeconds.ToString('F0')))s $($Command.Name)$($D.Keys.ForEach({" -${_}$(if(![string]::IsNullOrEmpty($D[$_])){" '$($D[$_])'"})"}) -join '')"
        $pool.SendInput($D)
        $r = $pool.ReceiveOutput()
        $pendingResults, $errorsRec, $warnings = $r.Item1, $r.Item2, $r.Item3
        foreach ($warning in $warnings) {
            Write-Warning $warning.Message
        }
        foreach ($e in $errorsRec) {
            Write-Error $e
        }
        Write-Output $pendingResults
    }

    end {
        Write-Verbose "[$i] ($($SW.Elapsed.TotalSeconds.ToString('F0')))s Waiting for completion ($([DateTime]::Now.ToString('HH:mm:ss')))"
        $r = $pool.WaitForAndCollectRemainingOutput()
        $results, $errorsRec, $warnings = $r.Item1, $r.Item2, $r.Item3
        foreach ($warning in $warnings) {
            Write-Warning $warning.Message
        }
        foreach ($e in $errorsRec) {
            Write-Error $e
        }
        foreach ($result in $results) {
            Write-Output $result
        }
        $SW.Stop()
        Write-Verbose "[$i] ($($SW.Elapsed.TotalSeconds.ToString('F0')))s end"
    }
}
Export-ModuleMember -Function New-CsOnlineLisLocationParallel

function Set-CsOnlineLisSubnetParallel {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium', PositionalBinding=$true)]
    param(
        [Parameter(Mandatory=$true, Position=0, ValueFromPipelineByPropertyName=$true)]
        [guid]
        ${LocationId},
    
        [Parameter(Mandatory=$true, Position=1, ValueFromPipelineByPropertyName=$true)]
        [string]
        ${Subnet},
    
        [Parameter(Position=2, ValueFromPipelineByPropertyName=$true)]
        [string]
        ${Description},
    
        [switch]
        ${Force}
    )

    begin {
        $SW = [Diagnostics.StopWatch]::StartNew()
        $Command = Get-Command -Name 'Set-CsOnlineLisSubnet'
        $CommonParametersToRemove = [Collections.Generic.List[string]]::new()
        $CommonParametersToRemove.AddRange([string[]]@("InformationVariable", "WarningVariable", "ErrorVariable"))
        $i = 0
        $pool = [Microsoft.Teams.ConfigApi.Cmdlets.CustomRunspacePool]::new($Command)
        $pool.Begin()
    }

    process {
        $i++
        $D = [Collections.Generic.Dictionary[string, object]]::new()
        $Keys = $PSBoundParameters.Keys
        foreach ($K in $Keys) {
            if ([string]::IsNullOrEmpty($K) -or ([string]::IsNullOrEmpty($PSItem.$K))) {
                continue
            }
            if ($K -in $CommonParametersToRemove) {
                continue
            }
            $D.Add($K, $PSItem.$K)
        }
        $DefaultAutoRestParams = [Microsoft.Teams.ConfigApi.Cmdlets.FlightingUtils]::GetFlightingCommandInfo($D, $Command.Name, 'Modern').DefaultAutoRestParameters
        foreach ($parameter in $DefaultAutoRestParams) {
            if ([string]::IsNullOrEmpty($parameter.Key) -or [string]::IsNullOrEmpty($parameter.Value)) {
                continue
            }
            $D.Add($parameter.Key, $parameter.Value)
        }
        Write-Verbose "[$i] ($($SW.Elapsed.TotalSeconds.ToString('F0')))s $($Command.Name)$($D.Keys.ForEach({" -${_}$(if(![string]::IsNullOrEmpty($D[$_])){" '$($D[$_])'"})"}) -join '')"
        $pool.SendInput($D)
        $r = $pool.ReceiveOutput()
        $pendingResults, $errorsRec, $warnings = $r.Item1, $r.Item2, $r.Item3
        foreach ($warning in $warnings) {
            Write-Warning $warning.Message
        }
        foreach ($e in $errorsRec) {
            Write-Error $e
        }
        Write-Output $pendingResults
    }

    end {
        Write-Verbose "[$i] ($($SW.Elapsed.TotalSeconds.ToString('F0')))s Waiting for completion ($([DateTime]::Now.ToString('HH:mm:ss')))"
        $r = $pool.WaitForAndCollectRemainingOutput()
        $results, $errorsRec, $warnings = $r.Item1, $r.Item2, $r.Item3
        foreach ($warning in $warnings) {
            Write-Warning $warning.Message
        }
        foreach ($e in $errorsRec) {
            Write-Error $e
        }
        foreach ($result in $results) {
            Write-Output $result
        }
        $SW.Stop()
        Write-Verbose "[$i] ($($SW.Elapsed.TotalSeconds.ToString('F0')))s end"
    }
}
Export-ModuleMember -Function Set-CsOnlineLisSubnetParallel

function Set-CsOnlineLisSwitchParallel {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium', PositionalBinding=$true)]
    param(
        [Parameter(Mandatory=$true, Position=0, ValueFromPipelineByPropertyName=$true)]
        [guid]
        ${LocationId},
    
        [Parameter(Mandatory=$true, Position=1, ValueFromPipelineByPropertyName=$true)]
        [string]
        ${ChassisId},
    
        [Parameter(Position=2, ValueFromPipelineByPropertyName=$true)]
        [string]
        ${Description},
    
        [switch]
        ${Force}
    )

    begin {
        $SW = [Diagnostics.StopWatch]::StartNew()
        $Command = Get-Command -Name 'Set-CsOnlineLisSwitch'
        $CommonParametersToRemove = [Collections.Generic.List[string]]::new()
        $CommonParametersToRemove.AddRange([string[]]@("InformationVariable", "WarningVariable", "ErrorVariable"))
        $i = 0
        $pool = [Microsoft.Teams.ConfigApi.Cmdlets.CustomRunspacePool]::new($Command)
        $pool.Begin()
    }

    process {
        $i++
        $D = [Collections.Generic.Dictionary[string, object]]::new()
        $Keys = $PSBoundParameters.Keys
        foreach ($K in $Keys) {
            if ([string]::IsNullOrEmpty($K) -or ([string]::IsNullOrEmpty($PSItem.$K))) {
                continue
            }
            if ($K -in $CommonParametersToRemove) {
                continue
            }
            $D.Add($K, $PSItem.$K)
        }
        $DefaultAutoRestParams = [Microsoft.Teams.ConfigApi.Cmdlets.FlightingUtils]::GetFlightingCommandInfo($D, $Command.Name, 'Modern').DefaultAutoRestParameters
        foreach ($parameter in $DefaultAutoRestParams) {
            if ([string]::IsNullOrEmpty($parameter.Key) -or [string]::IsNullOrEmpty($parameter.Value)) {
                continue
            }
            $D.Add($parameter.Key, $parameter.Value)
        }
        Write-Verbose "[$i] ($($SW.Elapsed.TotalSeconds.ToString('F0')))s $($Command.Name)$($D.Keys.ForEach({" -${_}$(if(![string]::IsNullOrEmpty($D[$_])){" '$($D[$_])'"})"}) -join '')"
        $pool.SendInput($D)
        $r = $pool.ReceiveOutput()
        $pendingResults, $errorsRec, $warnings = $r.Item1, $r.Item2, $r.Item3
        foreach ($warning in $warnings) {
            Write-Warning $warning.Message
        }
        foreach ($e in $errorsRec) {
            Write-Error $e
        }
        Write-Output $pendingResults
    }

    end {
        Write-Verbose "[$i] ($($SW.Elapsed.TotalSeconds.ToString('F0')))s Waiting for completion ($([DateTime]::Now.ToString('HH:mm:ss')))"
        $r = $pool.WaitForAndCollectRemainingOutput()
        $results, $errorsRec, $warnings = $r.Item1, $r.Item2, $r.Item3
        foreach ($warning in $warnings) {
            Write-Warning $warning.Message
        }
        foreach ($e in $errorsRec) {
            Write-Error $e
        }
        foreach ($result in $results) {
            Write-Output $result
        }
        $SW.Stop()
        Write-Verbose "[$i] ($($SW.Elapsed.TotalSeconds.ToString('F0')))s end"
    }
}
Export-ModuleMember -Function Set-CsOnlineLisSwitchParallel

function Set-CsOnlineLisPortParallel {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium', PositionalBinding=$true)]
    param(
        [Parameter(Mandatory=$true, Position=0, ValueFromPipelineByPropertyName=$true)]
        [guid]
        ${LocationId},
    
        [Parameter(Mandatory=$true, Position=1, ValueFromPipelineByPropertyName=$true)]
        [string]
        ${ChassisID},

        [Parameter(Mandatory=$true, Position=2, ValueFromPipelineByPropertyName=$true)]
        [string]
        ${PortID},
    
        [Parameter(Position=3, ValueFromPipelineByPropertyName=$true)]
        [string]
        ${Description},
    
        [switch]
        ${Force}
    )

    begin {
        $SW = [Diagnostics.StopWatch]::StartNew()
        $Command = Get-Command -Name 'Set-CsOnlineLisPort'
        $CommonParametersToRemove = [Collections.Generic.List[string]]::new()
        $CommonParametersToRemove.AddRange([string[]]@("InformationVariable", "WarningVariable", "ErrorVariable"))
        $i = 0
        $pool = [Microsoft.Teams.ConfigApi.Cmdlets.CustomRunspacePool]::new($Command)
        $pool.Begin()
    }

    process {
        $i++
        $D = [Collections.Generic.Dictionary[string, object]]::new()
        $Keys = $PSBoundParameters.Keys
        foreach ($K in $Keys) {
            if ([string]::IsNullOrEmpty($K) -or ([string]::IsNullOrEmpty($PSItem.$K))) {
                continue
            }
            if ($K -in $CommonParametersToRemove) {
                continue
            }
            $D.Add($K, $PSItem.$K)
        }
        $DefaultAutoRestParams = [Microsoft.Teams.ConfigApi.Cmdlets.FlightingUtils]::GetFlightingCommandInfo($D, $Command.Name, 'Modern').DefaultAutoRestParameters
        foreach ($parameter in $DefaultAutoRestParams) {
            if ([string]::IsNullOrEmpty($parameter.Key) -or [string]::IsNullOrEmpty($parameter.Value)) {
                continue
            }
            $D.Add($parameter.Key, $parameter.Value)
        }
        Write-Verbose "[$i] ($($SW.Elapsed.TotalSeconds.ToString('F0')))s $($Command.Name)$($D.Keys.ForEach({" -${_}$(if(![string]::IsNullOrEmpty($D[$_])){" '$($D[$_])'"})"}) -join '')"
        $pool.SendInput($D)
        $r = $pool.ReceiveOutput()
        $pendingResults, $errorsRec, $warnings = $r.Item1, $r.Item2, $r.Item3
        foreach ($warning in $warnings) {
            Write-Warning $warning.Message
        }
        foreach ($e in $errorsRec) {
            Write-Error $e
        }
        Write-Output $pendingResults
    }

    end {
        Write-Verbose "[$i] ($($SW.Elapsed.TotalSeconds.ToString('F0')))s Waiting for completion ($([DateTime]::Now.ToString('HH:mm:ss')))"
        $r = $pool.WaitForAndCollectRemainingOutput()
        $results, $errorsRec, $warnings = $r.Item1, $r.Item2, $r.Item3
        foreach ($warning in $warnings) {
            Write-Warning $warning.Message
        }
        foreach ($e in $errorsRec) {
            Write-Error $e
        }
        foreach ($result in $results) {
            Write-Output $result
        }
        $SW.Stop()
        Write-Verbose "[$i] ($($SW.Elapsed.TotalSeconds.ToString('F0')))s end"
    }
}
Export-ModuleMember -Function Set-CsOnlineLisPortParallel

function Set-CsOnlineLisWirelessAccessPointParallel {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium', PositionalBinding=$true)]
    param(
        [Parameter(Mandatory=$true, Position=0, ValueFromPipelineByPropertyName=$true)]
        [guid]
        ${LocationId},
    
        [Parameter(Mandatory=$true, Position=1, ValueFromPipelineByPropertyName=$true)]
        [string]
        ${BSSID},
    
        [Parameter(Position=2, ValueFromPipelineByPropertyName=$true)]
        [string]
        ${Description},
    
        [switch]
        ${Force}
    )

    begin {
        $SW = [Diagnostics.StopWatch]::StartNew()
        $Command = Get-Command -Name 'Set-CsOnlineLisWirelessAccessPoint'
        $CommonParametersToRemove = [Collections.Generic.List[string]]::new()
        $CommonParametersToRemove.AddRange([string[]]@("InformationVariable", "WarningVariable", "ErrorVariable"))
        $i = 0
        $pool = [Microsoft.Teams.ConfigApi.Cmdlets.CustomRunspacePool]::new($Command)
        $pool.Begin()
    }

    process {
        $i++
        $D = [Collections.Generic.Dictionary[string, object]]::new()
        $Keys = $PSBoundParameters.Keys
        foreach ($K in $Keys) {
            if ([string]::IsNullOrEmpty($K) -or ([string]::IsNullOrEmpty($PSItem.$K))) {
                continue
            }
            if ($K -in $CommonParametersToRemove) {
                continue
            }
            $D.Add($K, $PSItem.$K)
        }
        $DefaultAutoRestParams = [Microsoft.Teams.ConfigApi.Cmdlets.FlightingUtils]::GetFlightingCommandInfo($D, $Command.Name, 'Modern').DefaultAutoRestParameters
        foreach ($parameter in $DefaultAutoRestParams) {
            if ([string]::IsNullOrEmpty($parameter.Key) -or [string]::IsNullOrEmpty($parameter.Value)) {
                continue
            }
            $D.Add($parameter.Key, $parameter.Value)
        }
        Write-Verbose "[$i] ($($SW.Elapsed.TotalSeconds.ToString('F0')))s $($Command.Name)$($D.Keys.ForEach({" -${_}$(if(![string]::IsNullOrEmpty($D[$_])){" '$($D[$_])'"})"}) -join '')"
        $pool.SendInput($D)
        $r = $pool.ReceiveOutput()
        $pendingResults, $errorsRec, $warnings = $r.Item1, $r.Item2, $r.Item3
        foreach ($warning in $warnings) {
            Write-Warning $warning.Message
        }
        foreach ($e in $errorsRec) {
            Write-Error $e
        }
        Write-Output $pendingResults
    }

    end {
        Write-Verbose "[$i] ($($SW.Elapsed.TotalSeconds.ToString('F0')))s Waiting for completion ($([DateTime]::Now.ToString('HH:mm:ss')))"
        $r = $pool.WaitForAndCollectRemainingOutput()
        $results, $errorsRec, $warnings = $r.Item1, $r.Item2, $r.Item3
        foreach ($warning in $warnings) {
            Write-Warning $warning.Message
        }
        foreach ($e in $errorsRec) {
            Write-Error $e
        }
        foreach ($result in $results) {
            Write-Output $result
        }
        $SW.Stop()
        Write-Verbose "[$i] ($($SW.Elapsed.TotalSeconds.ToString('F0')))s end"
    }
}
Export-ModuleMember -Function Set-CsOnlineLisWirelessAccessPointParallel


