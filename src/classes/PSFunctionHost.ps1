class PSFunctionHost {
    [Diagnostics.Stopwatch] $vsw = [Diagnostics.Stopwatch]::new()
    [Management.Automation.PSCmdlet] $Cmdlet
    [PSFunctionHost] $Parent
    [int] $Processed = 0
    [int] $Total = 0
    [string] $Activity
    [long] $LastUpdate
    [long] $UpdateInterval
    [int] $Id
    [string] $LastMessage

    PSFunctionHost([Management.Automation.PSCmdlet] $Cmdlet, [string] $Activity, [long] $UpdateInterval) {
        $this.Cmdlet = $Cmdlet
        $this.Parent = $null
        $this.UpdateInterval = $UpdateInterval
        $this.Id = if ($null -eq $this.Cmdlet.MyInvocation.PipelinePosition) { 10 } else { 10 * $this.Cmdlet.MyInvocation.PipelinePosition }
        $this.Activity = $Activity
    }
    
    PSFunctionHost([PSFunctionHost] $Parent, [string] $Activity) {
        if ($null -eq $Parent) { throw 'Parent cannot be null' }
        $this.Activity = $Activity
        $this.Parent = $Parent
        $this.Id = $this.Parent.Id + 1
        $this.Cmdlet = $this.Parent.Cmdlet
        $this.UpdateInterval = $this.Parent.UpdateInterval
    }
    
    [void] ForceUpdate([string] $Status) {
        $this.LastUpdate = 0
        $this.Update($Status, $true)
    }

    [void] Update([bool] $increment, [string] $Status) {
        if ($increment) { $this.Processed++ }
        $this.Update($Status)
    }

    [void] Update([string] $Status) {
        $this.Update($Status, $false)
    }

    [void] Update([string] $Status, [bool] $Wait) {
        if ($this.LastUpdate -gt 0 -and ($this.vsw.ElapsedMilliseconds - $this.LastUpdate) -lt $this.UpdateInterval) { 
            if (!$Wait) { return }
            Start-Sleep -Milliseconds ([Math]::Max(10,($this.UpdateInterval - ($this.vsw.ElapsedMilliseconds - $this.LastUpdate))))
        }
        $this.LastMessage = $Status
        $ProgressString = ''
        $prog = [Management.Automation.ProgressRecord]::new($this.Id, $this.Activity, $Status)
        if ($null -ne $this.Parent) {
            $this.Parent.Update($this.Parent.LastMessage, $Wait)
            $prog.ParentActivityId = $this.Parent.Id
        }
        if ($this.Processed -gt 0) {
            $ProgressString = ' ({0})' -f $this.Processed
        }
        if ($this.Total -gt 0 -and $this.Processed -gt 0) {
            $ProgressString = ' ({0}/{1})' -f $this.Processed, $this.Total
            $prog.PercentComplete = [Math]::Max(0,[Math]::Min(100,[int](($this.Processed / [double]$this.Total) * 100)))
            $prog.SecondsRemaining = [Math]::Max(0,[int](($this.vsw.Elapsed.TotalSeconds / $this.Processed) * ($this.Total - $this.Processed)))
        }
        $prog.StatusDescription = '[{0:F3}s]{1} {2}' -f $this.vsw.Elapsed.TotalSeconds, $ProgressString, $Status
        $this.LastUpdate = $this.vsw.ElapsedMilliseconds
        if ($null -ne $this.Cmdlet) {
            $this.Cmdlet.WriteProgress($prog)
            return
        }
        $ProgHash = @{
            Activity = $prog.Activity
            Id       = $prog.ActivityId
            ParentId = $prog.ParentActivityId
            Status   = $prog.StatusDescription
        }
        if ($this.Total -gt 0 -and $this.Processed -gt 0) {
            $ProgHash['PercentComplete'] = $prog.PercentComplete
            $ProgHash['SecondsRemaining'] = $prog.SecondsRemaining
        }
        Write-Progress @ProgHash
    }

    [string] FormatMessage([string] $Message) {
        $act = "[$($this.Activity)]"
        $ParentMessage = ''
        if ($null -ne $this.Parent) {
            $ParentMessage = '[{0:F1}s] ' -f $this.Parent.vsw.Elapsed.TotalSeconds
            if ($null -ne $this.Cmdlet.MyInvocation.MyCommand.Name) {
                $ParentMessage = '{0}[{1}] ' -f $ParentMessage, $this.Cmdlet.MyInvocation.MyCommand.Name
            }
            return '{0}{1} [{2:F3}s] {3}' -f $ParentMessage, $act, $this.vsw.Elapsed.TotalSeconds, $Message
        }
        if ($null -ne $this.Cmdlet.MyInvocation.MyCommand.Name) {
            $ParentMessage = ' [{1}]' -f $ParentMessage, $this.Cmdlet.MyInvocation.MyCommand.Name
        }
        return '[{0:F1}s]{1} {2}' -f $this.vsw.Elapsed.TotalSeconds, $ParentMessage, $Message
    }

    [void] WriteVerbose([string] $Message) {
        if ($null -ne $this.Cmdlet) {
            $this.Cmdlet.WriteVerbose($this.FormatMessage($Message))
            return
        }
        Write-Verbose $this.FormatMessage($Message)
    }

    [void] WriteWarning([string] $Message) {
        if ($null -ne $this.Cmdlet) {
            $this.Cmdlet.WriteWarning($this.FormatMessage($Message))
            return
        }
        Write-Warning $this.FormatMessage($Message)
    }

    [void] WriteInformation([string] $Message) {
        if ($null -ne $this.Cmdlet) {
            $this.Cmdlet.WriteInformation($this.FormatMessage($Message), @())
            return
        }
        Write-Information $this.FormatMessage($Message)
    }

    [void] Complete() {
        $prog = [Management.Automation.ProgressRecord]::new($this.Id, $this.Activity, 'Complete')
        $prog.PercentComplete = 100
        $prog.SecondsRemaining = 0
        $prog.RecordType = [Management.Automation.ProgressRecordType]::Completed
        $this.Cmdlet.WriteProgress($prog)
        $this.vsw.Stop()
    }

    [void] Restart() {
        $this.vsw.Restart()
        $this.Processed = 0
        $this.Total = 0
        $this.ForceUpdate('Processing...')
    }

    static [PSFunctionHost] StartNew([Management.Automation.PSCmdlet] $Cmdlet, [string] $Activity, [long] $UpdateInterval) {
        $newHelper = [PSFunctionHost]::new($Cmdlet, $Activity, $UpdateInterval)
        $newHelper.Restart()
        return $newHelper
    }

    static [PSFunctionHost] StartNew([PSFunctionHost] $Parent, [string] $Activity) {
        $newHelper = [PSFunctionHost]::new($Parent, $Activity)
        $newHelper.Restart()
        return $newHelper
    }
}