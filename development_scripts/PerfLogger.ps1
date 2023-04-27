using namespace System.Collections.Generic

class MethodInvocationInfo {
    [string] $File
    [string] $Source
    [string] $Method
    [int] $Line
    [int] $Id
}
class MethodTrace {
    [long] $StartTicks
    [long] $EndTicks
    [int] $MethodId

    hidden static [Text.StringBuilder] $_sb = [Text.StringBuilder]::new()
    [string] ToJsonString() {
        return [MethodTrace]::_sb.Clear().Append('[').Append($this.MethodId).Append(',').Append($this.StartTicks).Append(',').Append($this.EndTicks).Append(']').ToString()
    }
    [void] OffsetTicks([long] $minimum) {
        $this.StartTicks -= $minimum
        $this.EndTicks -= $minimum
    }
}
class StackHistory {
    [int[]] $StackIds
    [long] $StartTicks
    [long] $EndTicks
    StackHistory([MethodTrace] $lastTrace) {
        $this.StartTicks = $lastTrace.StartTicks
        $this.EndTicks = $lastTrace.EndTicks
        $this.StackIds = [int[]]::new([PerfLogger]::CallStack.Count + 1)
        $this.StackIds[0] = $lastTrace.MethodId
        [PerfLogger]::CallStack.CopyTo($this.StackIds, 1)
        [Array]::Reverse($this.StackIds)
    }
    StackHistory([long] $ts) {
        $this.StartTicks = [PerfLogger]::Timestamps.Peek()
        $this.EndTicks = $ts
        $this.StackIds = [int[]]::new([PerfLogger]::CallStack.Count)
        [PerfLogger]::CallStack.CopyTo($this.StackIds, 0)
        [Array]::Reverse($this.StackIds)
    }
    hidden static [Text.StringBuilder] $_sb = [Text.StringBuilder]::new()
    [string] ToJsonString() {
        $sb = [StackHistory]::_sb
        $sb.Clear().Append('[').Append($this.StartTicks).Append(',').Append($this.EndTicks).Append(',[')
        foreach ($id in $this.StackIds) {
            $sb.Append($id).Append(',')
        }
        if ($this.StackIds.Count -gt 0) {
            $sb.Length--
        }
        $sb.Append(']]')
        return $sb.ToString()
    }
    [void] OffsetTicks([long] $minimum) {
        $this.StartTicks -= $minimum
        $this.EndTicks -= $minimum
    }
}
class PerfLogger {
    static [MethodInvocationInfo[]] $Methods = @(<#-# this statically AOT #-#>)
    static [HashSet[int]] $Ignored = @()
    static [List[StackHistory]] $StackHistory = @()
    static [List[MethodTrace]] $MethodHistory = @()
    static [Stack[int]] $CallStack = @()
    static [Stack[long]] $Timestamps = @()
    static [long] $LastMethodSample = [DateTime]::Now.Ticks
    static [long] $LastStackSample = [DateTime]::Now.Ticks
    static [long] $SampleThresholdMs <#-# SAMPLERATEMS #-#>
    static [void] Enter([int] $id) {
        if ([PerfLogger]::Ignored.Contains($id)) { return }
        if ($id -ge [PerfLogger]::Methods.Count) {
            throw 'Method Id not found'
        }
        if ([PerfLogger]::_hasMinimized) {
            Write-Warning 'PerfLogger has been minimized, clearing history...'
            [PerfLogger]::_hasMinimized = $false
            [PerfLogger]::StackHistory.Clear()
            [PerfLogger]::MethodHistory.Clear()
            [PerfLogger]::LastMethodSample = [DateTime]::Now.Ticks
            [PerfLogger]::LastStackSample = [DateTime]::Now.Ticks
        }
        $ts = [DateTime]::Now.Ticks
        [PerfLogger]::CallStack.Push($id)
        [PerfLogger]::Timestamps.Push($ts)
    }
    static [void] Exit([int] $id) {
        if ([PerfLogger]::Ignored.Contains($id)) { return }
        if ([PerfLogger]::CallStack.Count -eq 0) {
            throw 'CallStack Empty'
        }
        $stackId = [PerfLogger]::CallStack.Pop()
        if ($stackId -ne $id) {
            [PerfLogger]::CallStack.Push($stackId)
            throw 'Unexpected Method Id'
        }
        $start = [PerfLogger]::Timestamps.Pop()
        if ([PerfLogger]::_hasMinimized) {
            Write-Warning 'PerfLogger has been minimized, clearing history...'
            [PerfLogger]::_hasMinimized = $false
            [PerfLogger]::StackHistory.Clear()
            [PerfLogger]::MethodHistory.Clear()
            [PerfLogger]::LastMethodSample = [DateTime]::Now.Ticks
            [PerfLogger]::LastStackSample = [DateTime]::Now.Ticks
        }
        $end = [DateTime]::Now.Ticks
        if ($end -ge ([PerfLogger]::LastMethodSample + [PerfLogger]::SampleThresholdMs * 10000)) {
            [PerfLogger]::LastMethodSample = $end
            $methodTrace = [MethodTrace]@{
                StartTicks = $start
                EndTicks   = $end
                MethodId   = $id
            }
            [PerfLogger]::MethodHistory.Add($methodTrace)
            if ($end -ge ([PerfLogger]::LastStackSample + [PerfLogger]::SampleThresholdMs * 10000)) {
                [PerfLogger]::LastStackSample = $end
                [PerfLogger]::StackHistory.Add($methodTrace)
            }
        }
    }

    hidden static [bool] $_hasMinimized = $false

    static [void] Minimize() {
        if ([PerfLogger]::_hasMinimized) { return }
        [PerfLogger]::_hasMinimized = $true
        $min = [PerfLogger]::StackHistory[0].StartTicks
        if ([PerfLogger]::MethodHistory[0].StartTicks -lt $min) {
            $min = [PerfLogger]::MethodHistory[0].StartTicks
        }
        for ($i = 0; $i -lt [PerfLogger]::StackHistory.Count; $i++) {
            [PerfLogger]::StackHistory[$i].OffsetTicks($min)
        }
        for ($i = 0; $i -lt [PerfLogger]::MethodHistory.Count; $i++) {
            [PerfLogger]::MethodHistory[$i].OffsetTicks($min)
        }
    }

    static [string] GetStackHistoryJson() {
        [PerfLogger]::Minimize()
        $sb = [Text.StringBuilder]::new()
        $sb.Append('[')
        for ($i = 0; $i -lt [PerfLogger]::StackHistory.Count; $i++) {
            $sb.Append([PerfLogger]::StackHistory[$i].ToJsonString()).Append(',')
        }
        if ([PerfLogger]::StackHistory.Count -gt 0) {
            $sb.Length--
        }
        $sb.Append(']')
        return $sb.ToString()
    }

    static [string] GetMethodHistoryJson() {
        [PerfLogger]::Minimize()
        $sb = [Text.StringBuilder]::new()
        $sb.Append('[')
        for ($i = 0; $i -lt [PerfLogger]::MethodHistory.Count; $i++) {
            $sb.Append([PerfLogger]::MethodHistory[$i].ToJsonString()).Append(',')
        }
        if ([PerfLogger]::MethodHistory.Count -gt 0) {
            $sb.Length--
        }
        $sb.Append(']')
        return $sb.ToString()
    }
}