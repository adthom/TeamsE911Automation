using namespace System.Timers
using namespace System.Management.Automation
using namespace System.Management.Automation.Language
using namespace System.Reflection
using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.Collections.Concurrent
using namespace System.Diagnostics.Tracing
using namespace System.IO
using namespace System.Linq

class PSTracer : Timer {
    hidden [Debugger] $debugger
    hidden [void] set_debugger([Debugger] $value) { throw [PSTracer]::GetException('debugger','readonly') }

    hidden [PSEventJob] $Job = $null
    hidden [PSEventJob] get_Job() { throw [PSTracer]::GetException('Job','private') }
    hidden [void] set_Job([PSEventJob] $value) { throw [PSTracer]::GetException('Job','readonly') }

    hidden [object] $_lockObj = [object]::new()
    hidden [void] set__lockObj([object] $value) { throw [PSTracer]::GetException('_lockObj','readonly') }

    hidden [Diagnostics.Stopwatch] $Stopwatch = [Diagnostics.Stopwatch]::new()
    hidden [Diagnostics.Stopwatch] get_Stopwatch() { throw [PSTracer]::GetException('Stopwatch','private') }
    hidden [void] set_Stopwatch([Diagnostics.Stopwatch] $value) { throw [PSTracer]::GetException('Stopwatch','readonly') }

    hidden [ConcurrentDictionary[DateTime, List[CallStackFrame]]] $Samples = @{}
    hidden [void] set_Samples([ConcurrentDictionary[DateTime, List[CallStackFrame]]] $value) { throw [PSTracer]::GetException('Samples','readonly') }

    [string] $Id
    hidden [void] set_Id([string] $value) { throw [PSTracer]::GetException('Id','readonly') }

    [int] $MissedEvents = 0
    hidden [void] set_MissedEvents([int] $value) { throw [PSTracer]::GetException('MissedEvents','readonly') }
    
    PSTracer() : base(1000.0) {
        $this.Id = [Guid]::NewGuid().ToString('N')
        $this.debugger = [PSTracer]::GetDebuggerFromContext()
    }

    PSTracer([double] $sampleIntervalMs) : base($sampleIntervalMs) {
        $this.Id = [Guid]::NewGuid().ToString('N')
        $this.debugger = [PSTracer]::GetDebuggerFromContext()
    }

    PSTracer([Debugger] $debugger) : base(1000.0) {
        $this.Id = [Guid]::NewGuid().ToString('N')
        $this.debugger = $debugger
    }

    PSTracer([Debugger] $debugger, [double] $sampleIntervalMs) : base($sampleIntervalMs) {
        $this.Id = [Guid]::NewGuid().ToString('N')
        $this.debugger = $debugger
    }

    hidden [GCStats] $GCStart = [GCStats]::Empty
    hidden [GCStats] get_GCStart() { throw [PSTracer]::GetException('GCStart','private') }
    hidden [void] set_GCStart([GCStats] $value) { throw [PSTracer]::GetException('GCStart','readonly') }
    
    hidden [GCStats] $GCEnd = [GCStats]::Empty
    hidden [GCStats] get_GCEnd() { throw [PSTracer]::GetException('GCEnd','private') }
    hidden [void] set_GCEnd([GCStats] $value) { throw [PSTracer]::GetException('GCEnd','readonly') }

    [GCStats] $GCStats = [GCStats]::Empty
    hidden [void] set_GCStats([GCStats] $value) { throw [PSTracer]::GetException('GCStats','readonly') }

    [void] Start() {
        if ($this.disposed) { throw 'PSTracer is disposed' }
        $this.ForceGC()
        $this.GCStart = [GCStats]::ReadInitital()
        if ($null -eq $this.Job) {
            $objectEventArgs = @{
                InputObject = $this
                EventName = 'Elapsed'
                SourceIdentifier = $this.Id
                Action = {
                    $lockTaken = $false
                    [Threading.Monitor]::Enter($Sender._lockObj, [ref]$lockTaken)
                    try {
                        $delta = [DateTime]::Now - $EventArgs.SignalTime
                        if ($delta -lt [Timespan]::FromMilliseconds($Sender.Interval)) {
                            $stack = [CallStackFrame[]]$Sender.debugger.GetCallStack().Where({!$_.Location.StartsWith('Tracing.psm1')},'SkipUntil').Where({$_.Location.StartsWith('Tracing.psm1')},'Until')
                            # $stack = [CallStackFrame[]]($stack[1..($stack.Length - 1)])
                            $Sender.Samples.TryAdd($EventArgs.SignalTime, $stack)
                        }                   
                        else {
                            $Sender.MissedEvents++
                        }
                    }
                    finally {
                        if ($lockTaken) {
                            [Threading.Monitor]::Exit($Sender._lockObj)
                        }
                    }
                }
                ErrorAction = 'Stop'
            }
            ([Timer]$this).AutoReset = $true
            $this.Job = Register-ObjectEvent @objectEventArgs
        }
        $this.Stopwatch.Start()
        ([Timer]$this).Enabled = $true
    }

    [void] Stop() {
        if ($this.disposed) { throw 'PSTracer is disposed' }
        $this.Stopwatch.Stop()
        $this.GCEnd = [GCStats]::ReadFinal()
        $this.GCStats += $this.GCEnd - $this.GCStart
        ([Timer]$this).Enabled = $false
    }

    [void] Finish() {
        $this.Stop()
        if ($null -eq $this.Job) { return }
        try {
            $this.Job.StopJob()
            $this.Job.Dispose()
            $this.Job = $null
        }
        catch {
            Write-Warning "Failed to stop event for $($this.Id): $($_.Exception.Message)"
        }
    }

    [void] Restart() {
        $this.Stop()
        $this.Samples.Clear()
        $this.Stopwatch.Reset()
        $this.MissedEvents = 0
        $this.Start()
    }

    [DateTime] SessionStart() {
        return [Enumerable]::FirstOrDefault([Enumerable]::OrderBy($this.Samples.Keys, [Func[DateTime,bool]]{$args[0]}))
    }

    hidden [void] ForceGC() {
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
        [GC]::Collect()
    }

    hidden [bool] get_AutoReset() { throw [PSTracer]::GetException('AutoReset','private') }
    hidden [void] set_AutoReset([bool] $value) { throw [PSTracer]::GetException('AutoReset','readonly') }
    hidden [bool] get_Enabled() { throw [PSTracer]::GetException('Enabled','private') }
    hidden [void] set_Enabled([bool] $value) { throw [PSTracer]::GetException('Enabled','readonly') }
    hidden [ComponentModel.IContainer] get_Container() { throw [PSTracer]::GetException('Container','private') }
    hidden [void] set_Container([ComponentModel.IContainer] $value) { throw [PSTracer]::GetException('Container','readonly') }
    hidden [ComponentModel.ISynchronizeInvoke] get_SynchronizingObject() { throw [PSTracer]::GetException('SynchronizingObject','private') }
    hidden [void] set_SynchronizingObject([ComponentModel.ISynchronizeInvoke] $value) { throw [PSTracer]::GetException('SynchronizingObject','readonly') }
    hidden [ComponentModel.ISite] get_Site() { throw [PSTracer]::GetException('Site','private') }
    hidden [void] set_Site([ComponentModel.ISite] $value) { throw [PSTracer]::GetException('Site','readonly') }

    hidden [bool] $disposed = $false
    hidden [bool] get_disposed() { throw [PSTracer]::GetException('disposed','private') }
    hidden [void] set_disposed([bool] $value) { throw [PSTracer]::GetException('disposed','readonly') }
    [void] Dispose() {
        if ($this.disposed) { return }
        $this.Finish()
        $this.disposed = $true
        ([Timer]$this).Dispose()
    }

    static PSTracer() {
        $Flags = [BindingFlags]::Instance -bor [BindingFlags]::Static -bor [BindingFlags]::Public -bor [BindingFlags]::NonPublic
        [PSTracer]::PipelineType = [Ref].Assembly.GetType('System.Management.Automation.Runspaces.LocalPipeline')
        [PSTracer]::ExecutionContextType = [Ref].Assembly.GetType('System.Management.Automation.ExecutionContext')
        [PSTracer]::GetExecutionContextFromTLSMethod = [PSTracer]::PipelineType.GetMethod('GetExecutionContextFromTLS',$Flags)
        [PSTracer]::DebuggerProperty = [PSTracer]::ExecutionContextType.GetProperty('Debugger',$Flags)
        [PSTracer] | Update-TypeData -MemberType ScriptProperty -MemberName 'Elapsed' -Value {
            [OutputType([TimeSpan])]
            param()
            return $this.Stopwatch.Elapsed
        } -Force
        $Properties = @('Id','Samples','GCStats','Interval','Elapsed','MissedEvents')
        [PSTracer] | Update-TypeData -DefaultDisplayPropertySet $Properties -DefaultKeyPropertySet $Properties -Force
    }

    hidden static [Type] $PipelineType
    hidden static [Type] get_PipelineType() { throw [PSTracer]::GetException('PipelineType','private') }
    hidden static [void] set_PipelineType([Type] $value) { throw [PSTracer]::GetException('PipelineType','readonly') }
    hidden static [Type] $ExecutionContextType
    hidden static [Type] get_ExecutionContextType() { throw [PSTracer]::GetException('ExecutionContextType','private') }
    hidden static [void] set_ExecutionContextType([Type] $value) { throw [PSTracer]::GetException('ExecutionContextType','readonly') }
    hidden static [MethodInfo] $GetExecutionContextFromTLSMethod
    hidden static [MethodInfo] get_GetExecutionContextFromTLSMethod() { throw [PSTracer]::GetException('GetExecutionContextFromTLSMethod','private') }
    hidden static [void] set_GetExecutionContextFromTLSMethod([MethodInfo] $value) { throw [PSTracer]::GetException('GetExecutionContextFromTLSMethod','readonly') }
    hidden static [PropertyInfo] $DebuggerProperty
    hidden static [PropertyInfo] get_DebuggerProperty() { throw [PSTracer]::GetException('DebuggerProperty','private') }
    hidden static [void] set_DebuggerProperty([PropertyInfo] $value) { throw [PSTracer]::GetException('DebuggerProperty','readonly') }

    static [Debugger] GetDebuggerFromContext() { return [PSTracer]::DebuggerProperty.GetValue([PSTracer]::GetExecutionContextFromTLSMethod.Invoke($null,@())) }
    hidden static [InvalidOperationException] GetException([string] $caller, [string] $type) { return [InvalidOperationException]::new(('{0} is {1}' -f $caller, $type)) }
}

class GCStats {
    [int] $Generation0Collections
    hidden [void] set_Generation0Collections([int] $value) { throw [PSTracer]::GCStats('Generation0Collections','readonly') }

    [int] $Generation1Collections
    hidden [void] set_Generation1Collections([int] $value) { throw [PSTracer]::GCStats('Generation1Collections','readonly') }

    [int] $Generation2Collections
    hidden [void] set_Generation2Collections([int] $value) { throw [PSTracer]::GCStats('Generation2Collections','readonly') }

    hidden [long] $AllocatedBytes
    hidden [long] get_AllocatedBytes() { throw [GCStats]::GetException('AllocatedBytes','private') }
    hidden [void] set_AllocatedBytes([long] $value) { throw [PSTracer]::GCStats('AllocatedBytes','readonly') }

    [long] $TotalOperations
    hidden [void] set_TotalOperations([long] $value) { throw [PSTracer]::GCStats('TotalOperations','readonly') }

    hidden GCStats([int] $Generation0Collections, [int] $Generation1Collections, [int] $Generation2Collections, [long] $AllocatedBytes, [long] $TotalOperations) {
        $this.Generation0Collections = $Generation0Collections
        $this.Generation1Collections = $Generation1Collections
        $this.Generation2Collections = $Generation2Collections
        $this.AllocatedBytes = $AllocatedBytes
        $this.TotalOperations = $TotalOperations
    }

    [int] GetCollectionsCount([int] $generation) {
        switch ($generation) {
            0 { return $this.Generation0Collections }
            1 { return $this.Generation1Collections }
            default { return $this.Generation2Collections }
        }
        throw 'Impossible'
    }
    
    [long] GetTotalAllocatedBytes([bool] $excludeAllocationQuantumSideEffects) {
        if (!$excludeAllocationQuantumSideEffects) {
            return $this.AllocatedBytes
        }
        if ($this.AllocatedBytes -le [GCStats]::AllocationQuantum) {
            return 0
        }
        return $this.AllocatedBytes
    }
    
    [GCStats] WithTotalOperations([long] $TotalOperations) {
        return $this + [GCStats]::new(0,0,0,0,$TotalOperations)
    }
    
    [long] GetBytesAllocatedPerOperation() {
        # this will cause an allocation... need to rethink how to check this value without allocating
        $FrameworkInfo = [Runtime.InteropServices.RuntimeInformation]::FrameworkDescription.Split(' ')
        $excludeAllocationQuantum = $FrameworkInfo.Count -ne 2 -or [Version]$FrameworkInfo[-1] -le [Version]'2.0'
        if ($this.GetTotalAllocatedBytes($excludeAllocationQuantum) -eq 0 -or $this.TotalOperations -eq 0) {
            return 0
        }
        return [Math]::Round(([double]$this.GetTotalAllocatedBytes($excludeAllocationQuantum)/$this.TotalOperations), [MidpointRounding]::ToEven)
    }

    [string] ToString() {
        return "$([GCStats]::Prefix) $($this.Generation0Collections) $($this.Generation1Collections) $($this.Generation2Collections) $($this.AllocatedBytes) $($this.TotalOperations)"
    }
    [bool] Equals([object] $obj) {
        $other = $obj -as [GCStats]
        if ($null -eq $other) { return $false }
        return $this.Generation0Collections -eq $other.Generation0Collections -and
            $this.Generation1Collections -eq $other.Generation1Collections -and
            $this.Generation2Collections -eq $other.Generation2Collections -and
            $this.AllocatedBytes -eq $other.AllocatedBytes -and
            $this.TotalOperations -eq $other.TotalOperations
    }
    [int] GetHashCode() {
        # yuck
        return $this.ToString().GetHashCode()
        # $hash = 17
        # $hash = $hash * 31 + $this.Generation0Collections
        # $hash = $hash * 31 + $this.Generation1Collections
        # $hash = $hash * 31 + $this.Generation2Collections
        # $hash = $hash * 31 + $this.AllocatedBytes
        # $hash = $hash * 31 + $this.TotalOperations
        # return $hash
    }

    static [GCStats] ReadInitital() {
        $Allocated = [GCStats]::GetAllocatedBytes()
        return [GCStats]::new(
            [GC]::CollectionCount(0),
            [GC]::CollectionCount(1),
            [GC]::CollectionCount(2),
            $Allocated,
            0
        )
    }
    static [GCStats] ReadFinal() {
        return [GCStats]::new(
            [GC]::CollectionCount(0),
            [GC]::CollectionCount(1),
            [GC]::CollectionCount(2),
            [GCStats]::GetAllocatedBytes(),
            0
        )
    }
    static [long] GetAllocatedBytes() {
        [GC]::Collect()
        if ($null -ne [GCStats]::GetTotalAllocatedBytesDelegate) {
            return [GCStats]::GetTotalAllocatedBytesDelegate.Invoke($true)
        }
        if ($null -ne [GCStats]::GetAllocatedBytesForCurrentThreadMethod) {
            return [GCStats]::GetAllocatedBytesForCurrentThreadMethod.Invoke()
        }
        return 0l
    }

    hidden static [GCStats] op_Addition([GCStats] $left, [GCStats] $right) {
        return [GCStats]::new(
            $left.Generation0Collections + $right.Generation0Collections,
            $left.Generation1Collections + $right.Generation1Collections,
            $left.Generation2Collections + $right.Generation2Collections,
            $left.AllocatedBytes + $right.AllocatedBytes,
            $left.TotalOperations + $right.TotalOperations
        )
    }
    hidden static [GCStats] op_Subtraction([GCStats] $left, [GCStats] $right) {
        return [GCStats]::new(
            [Math]::Max(0,$left.Generation0Collections - $right.Generation0Collections),
            [Math]::Max(0,$left.Generation1Collections - $right.Generation1Collections),
            [Math]::Max(0,$left.Generation2Collections - $right.Generation2Collections),
            [Math]::Max(0l,$left.AllocatedBytes - $right.AllocatedBytes),
            [Math]::Max(0l,$left.TotalOperations - $right.TotalOperations)
        )
    }

    static [long] $AllocationQuantum
    static [void] set_AllocationQuantum([long] $value) { throw [GCStats]::GetException('AllocationQuantum', 'readonly') }

    hidden static [long] CalculateAllocationQuantumSize() {
        [long] $result = $null
        [int] $retry = 0
        do {
            if ((++$retry) -gt 10) {
                $result = 8192
                break
            }
            [GC]::Collect()
            [GC]::WaitForPendingFinalizers()
            [GC]::Collect()

            $result = [GC]::GetTotalMemory($false)
            $tmp = [object]::new()
            $result = [GC]::GetTotalMemory($false) - $result
            [GC]::KeepAlive($tmp)
        } while ($result -le 0)
        return $result
    }
    static [GCStats] Parse([string] $string) {
        if ($null -eq $string -or !$string.StartsWith([GCStats]::Prefix)) {
            throw [NotSupportedException]::new(('Line must start with {0}' -f [GCStats]::Prefix))
        }
        $parts = $string.Substring([GCStats]::Prefix.Length).Split(' ', [StringSplitOptions]::RemoveEmptyEntries)
        [int]$gen0 = $null
        [int]$gen1 = $null
        [int]$gen2 = $null
        [long]$allocated = $null
        [long]$total = $null
        if (![int]::TryParse($parts[0], [ref]$gen0) -or
            ![int]::TryParse($parts[1], [ref]$gen1) -or
            ![int]::TryParse($parts[2], [ref]$gen2) -or
            ![long]::TryParse($parts[3], [ref]$allocated) -or
            ![long]::TryParse($parts[4], [ref]$total)) {
            throw [FormatException]::new('Invalid format')
        }
        return [GCStats]::new($gen0, $gen1, $gen2, $allocated, $total)
    }
    static [GCStats] $Empty = [GCStats]::new(0,0,0,0,0)
    hidden static [void] set_Empty([GCStats] $value) { throw [GCStats]::GetException('Empty','readonly') }

    static GCStats() {
        $Flags = [BindingFlags]::Instance -bor [BindingFlags]::Static -bor [BindingFlags]::Public -bor [BindingFlags]::NonPublic
        [GCStats]::GetAllocatedBytesForCurrentThreadMethod = [GC].GetMethod('GetAllocatedBytesForCurrentThread', $Flags).CreateDelegate([Func[long]])
        $FrameworkInfo = [Runtime.InteropServices.RuntimeInformation]::FrameworkDescription.Split(' ')
        # .NET Core 3.0 and later (.NET Framework will be of length 3)
        if ($FrameworkInfo.Count -eq 2 -and [Version]$FrameworkInfo[-1] -ge [Version]'3.0') {
            [GCStats]::GetTotalAllocatedBytesMethod = [GC].GetMethod('GetTotalAllocatedBytes', $Flags).CreateDelegate([Func[bool,long]])
        }
        [GCStats]::AllocationQuantum = [GCStats]::CalculateAllocationQuantumSize()
    }
    hidden static [Func[long]] $GetAllocatedBytesForCurrentThreadMethod
    hidden static [Func[long]] get_GetAllocatedBytesForCurrentThreadMethod() { throw [GCStats]::GetException('GetAllocatedBytesForCurrentThreadMethod', 'private') }
    hidden static [void] set_GetAllocatedBytesForCurrentThreadMethod([Func[long]] $value) { throw [GCStats]::GetException('GetAllocatedBytesForCurrentThreadMethod', 'readonly') }

    hidden static [Func[bool,long]] $GetTotalAllocatedBytesMethod
    hidden static [Func[bool,long]] get_GetTotalAllocatedBytesMethod() { throw [GCStats]::GetException('GetTotalAllocatedBytesMethod', 'private') }
    hidden static [void] set_GetTotalAllocatedBytesMethod([Func[bool,long]] $value) { throw [GCStats]::GetException('GetTotalAllocatedBytesMethod', 'readonly') }

    hidden static [string] $Prefix = '# GC: '
    hidden static [string] get_Prefix() { throw [GCStats]::GetException('Prefix', 'private') }
    hidden static [void] set_Prefix([string] $value) { throw [GCStats]::GetException('Prefix', 'readonly') }

    hidden static [InvalidOperationException] GetException([string] $caller, [string] $type) { return [InvalidOperationException]::new(('{0} is {1}' -f $caller, $type)) }
}

class StringArrayComparer : IComparer[string[]] {
    [int] Compare([string[]] $x, [string[]] $y) {
        for ($i = 0; $i -lt $x.Length; $i++) {
            if ($i -ge $y.Length) { return 1 }
            if ($x[$i] -ne $y[$i]) { return $x[$i].CompareTo($y[$i]) }
        }
        if ($y.Length -gt $x.Length) { return -1 }
        return 0
    }
}

class rgbcolor {
    [byte] $R
    [byte] $G
    [byte] $B
    rgbcolor() {}
    rgbcolor([byte] $r, [byte] $g, [byte] $b) {
        $this.R = $r
        $this.G = $g
        $this.B = $b
    }
    rgbcolor([string] $rgbcolor) {
        $rgbcolor = $rgbcolor.Substring(4).TrimEnd(')')
        $parts = $rgbcolor.Split(',')
        $this.R = [byte]($parts[0])
        $this.G = [byte]($parts[1])
        $this.B = [byte]($parts[2])
    }
    [string] ToString() {
        return "rgb($($this.R),$($this.G),$($this.B))"
    }
}

class FlameGraphBar {
    [string] $Title
    [int] $Samples
    [int] $XIndexStart
    [int] $YIndex
    FlameGraphBar([string] $title, [object[]] $arguments) {
        $this.Title = $title
        $this.Samples = $arguments[0]
        $this.XIndexStart = $arguments[1]
        $this.YIndex = $arguments[2]
    }
    FlameGraphBar() {}
}

class HotFlameGraphBuilder {
    [FlameGraphBar[]] $Bars
    [string] $Title
    [int] $ViewWidth = 1280
    [int] $ViewHeight = 720
    [int] $XPadding = 10
    [int] $YPaddingRows = 2
    [int] $MaxDepth = 1
    [int] $MinDepth = 0
    [int] $TotalSamples = 0
    [double] $XScaleFactor = 1
    
    [string] $FontFamily = 'Verdana'
    [int] $FontSize = 12

    [rgbcolor] $fontColor = [rgbcolor]::new(0,0,0)

    # [SortedSet[double]] $RelativeWidthsSorted = @()
    [Dictionary[string, int]] $TitlesSorted = @{}
    [Dictionary[string, double]] $RelativeWidthsSorted = @{}
    [Dictionary[string,rgbcolor]] $ColorMap = @{}
    [double] $MinWeight = [double]::MaxValue
    [double] $MaxWeight = [double]::MinValue

    HotFlameGraphBuilder([FlameGraphBar[]] $bars, [int] $totalSamples, [string] $title, [int] $viewwidth, [int] $viewheight) {
        $this.Bars = $bars
        $this.Title = $title
        $this.ViewWidth = $viewwidth
        $this.ViewHeight = $viewheight
        $this.MinDepth = ($bars | Measure-Object -Property YIndex -Minimum).Minimum
        $this.MaxDepth = ($bars | Measure-Object -Property YIndex -Maximum).Maximum - $this.MinDepth
        $this.TotalSamples = $totalSamples
    }

    static [string] GetFlameGraph([FlameGraphBar[]] $bars, [int] $totalSamples, [string] $title, [int] $viewwidth, [int] $viewheight) {
        return [HotFlameGraphBuilder]::new($bars, $totalSamples, $title, $viewwidth, $viewheight).Build()
    }

    [string] Build() {
        return [Text.StringBuilder]::new().Append($this.GetHeader()).Append($this.GetBody()).Append('</svg>')
    }

    hidden [string] GetHeader() {
        $sb = [Text.StringBuilder]::new()
        $header = [HotFlameGraphBuilder]::GetHeaderTemplate() -f $this.ViewWidth, $this.ViewHeight
        $sb.AppendLine($header)
        # x appears have a full 10px of padding on the left and right
        $sb.AppendFormat('    <text text-anchor="middle" x="{0:0.00}" y="{1:0.#}" font-size="{2}" font-family="{3}" fill="{4}">{5}</text>', $this.ViewWidth/2, $this.GetYPosition(-1), [math]::Floor(1.45*$this.FontSize), $this.FontFamily, $this.fontColor, $this.Title).AppendLine()
        $sb.AppendFormat('    <text text-anchor="" x="{0:0.0}" y="{1:0.#}" font-size="{2}" font-family="{3}" fill="{4}" id="details"></text>', $this.GetXPosition(0), $this.GetYPosition($this.MaxDepth + 1), $this.FontSize, $this.FontFamily, $this.fontColor).AppendLine()
        $sb.AppendFormat('    <text text-anchor="" x="{0:0.0}" y="{1:0.#}" font-size="{2}" font-family="{3}" fill="{4}" id="unzoom" onclick="unzoom()" style="opacity:0.0;cursor:pointer">Reset Zoom</text>', $this.GetXPosition(0), $this.GetYPosition(-1), $this.FontSize, $this.FontFamily, $this.fontColor).AppendLine()
        return $sb.ToString()
    }

    hidden [void] RankBars() {
        $this.RelativeWidthsSorted.Clear()
        $this.TitlesSorted.Clear()
        [HashSet[string]] $seen = @()
        foreach ($bar in $this.Bars) {
            if ($seen.Contains($bar.Title)) {
                $this.TitlesSorted[$bar.Title] += $bar.Samples
                continue
            }
            $seen.Add($bar.Title)
            $this.TitlesSorted.Add($bar.Title, $bar.Samples)
        }
        foreach ($key in $this.TitlesSorted.Keys) {
            $this.RelativeWidthsSorted[$key] = $this.GetRelativeBarWith($this.TitlesSorted[$key])
        }
        $arr = [double[]]$this.RelativeWidthsSorted.Values
        $this.MinWeight = $arr[0]
        $this.MaxWeight = $arr[-1]
        $spread = $this.MaxWeight - $this.MinWeight

        # build the colormap
        foreach ($key in $this.RelativeWidthsSorted.Keys) {
            $relWeight = $this.RelativeWidthsSorted[$key]
            $index = $arr.IndexOf($relWeight)
            $pct = ([double]$relWeight - $this.MinWeight)/$spread
            $instancePct = ([double]$index)/($arr.Count - 1)
            $weightedPct = ($pct + $instancePct) / 2
            $g = [Math]::Round(255 * ($weightedPct))
            $this.ColorMap[$key] = [rgbcolor]::new(255, $g, 0)
        }
    }

    hidden [void] AppendBar([Text.StringBuilder] $sb, [FlameGraphBar] $bar) {
        $bartitle = '{0} ({1} samples, {2:0.00}%)' -f [Web.HttpUtility]::HtmlEncode($bar.Title), $bar.Samples, (100*(([double]$bar.Samples)/$this.TotalSamples))
        $sb.AppendFormat('    <g class="func_g" onmouseover="s(''{0}'')" onmouseout="c()" onclick="zoom(this)">', $bartitle).AppendLine()
        $sb.AppendFormat('        <title>{0}</title>', $bartitle).AppendLine()
        $sb.AppendFormat('        <rect x="{0:0.0}" y="{1:0.#}" width="{2:0.0}" height="{3:0.0}" fill="{4}" rx="2" ry="2" />', $this.GetXPosition($bar.XIndexStart), $this.GetYPosition($bar.YIndex), $this.GetRelativeBarWith($bar.Samples), $this.GetRowHeight()-1, $this.GetColor($bar.Title)).AppendLine()
        # $sb.AppendFormat('        <text text-anchor="" x="{0:0.0}" y="{1:0.#}" font-size="{2}" font-family="{3}" fill="{4}"></text>', $this.GetXPosition($bar.XIndexStart) + 3, $this.GetYPosition($bar.YIndex) + (($this.GetRowHeight()-1)/3), $this.FontSize, $this.FontFamily, $this.fontColor).AppendLine()
        $sb.AppendFormat('        <text text-anchor="" x="{0:0.0}" y="{1:0.#}" font-size="{2}" font-family="{3}" fill="{4}"></text>', $this.GetXPosition($bar.XIndexStart) + 3, $this.GetYPosition($bar.YIndex) + $this.FontSize, $this.FontSize, $this.FontFamily, $this.fontColor).AppendLine()
        $sb.AppendFormat('    </g>').AppendLine()
    }

    hidden [string] GetBody() {
        $sb = [System.Text.StringBuilder]::new()
        foreach ($bar in $this.Bars) {
            $this.AppendBar($sb, $bar)
        }
        return $sb.ToString()
    }

    hidden [int] GetTotalRows() {
        return ($this.MaxDepth - $this.MinDepth) + (2 * $this.YPaddingRows) + 1
    }

    hidden [double] GetRowHeight() {
        # 2 leading rows, 2 trailing rows
        return [Math]::Floor($this.ViewHeight / $this.GetTotalRows()) - 1
    }

    hidden [double] GetYMin() {
        return ($this.YPaddingRows + 1) * $this.GetRowHeight()
    }

    hidden [double] GetYMax() {
        return $this.ViewHeight - (($this.YPaddingRows) * $this.GetRowHeight())
    }

    hidden [double] GetYPosition([int] $index) {
        if ($index -lt 0) { 
            return $this.GetYMin() + (($index - 1) * $this.GetRowHeight())
        }
        return $this.GetYMin() + ((($this.MaxDepth - ($index - $this.MinDepth) - 1)) * $this.GetRowHeight())
    }

    hidden [double] GetRelativeBarWith([int] $samples) {
        return $this.GetBarWidth() * $samples
    }

    hidden [double] GetXMin() {
        return $this.XPadding
    }

    hidden [double] GetXMax() {
        return $this.ViewWidth - $this.XPadding
    }

    hidden [double] GetBarWidth() {
        $width = $this.GetXMax() - $this.GetXMin()
        $barWidth = [Math]::Round($width/[double]$this.TotalSamples,2)
        $this.XScaleFactor = $this.TotalSamples / [Math]::Round($width/$barWidth,0)
        if (($this.XScaleFactor * $this.TotalSamples) -gt ($this.XPadding/$width)) {
            $barWidth = [Math]::Round($width/[double]$this.TotalSamples,3)
            $this.XScaleFactor = $this.TotalSamples / [Math]::Round($width/$barWidth,0)
        }
        return $barWidth
    }

    hidden [double] GetXPosition([int] $index) {
        return $this.GetXMin() + ($index * $this.GetBarWidth())
    }

    hidden [rgbcolor] GetColor([string] $title) {
        if ($this.RelativeWidthsSorted.Count -eq 0) {
            $this.RankBars()
        }
        return $this.ColorMap[$title]
    }

    hidden [rgbcolor] GetColor() {
        $R = 205..254 | Get-Random
        $G = 0..229 | Get-Random
        $B = 0..54 | Get-Random
        return [rgbcolor]::new($R, $G, $B)
    }

    hidden static [string] $_headerTemplate
    hidden static [string] GetHeaderTemplate() {
        if ([string]::IsNullOrEmpty([HotFlameGraphBuilder]::_headerTemplate)) {
            [HotFlameGraphBuilder]::_headerTemplate = [Text.StringBuilder]::new().
            AppendLine('<?xml version="1.0" standalone="no"?>').
            AppendLine('<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">').
            AppendLine('<svg version="1.1" width="{0}" height="{1}" onload="init(evt)" viewBox="0 0 {0} {1}" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">').
            AppendLine('    <defs >').
            AppendLine('        <linearGradient id="background" y1="0" y2="1" x1="0" x2="0">').
            AppendLine('            <stop stop-color="#eeeeee" offset="5%" />').
            AppendLine('            <stop stop-color="#eeeeb0" offset="95%" />').
            AppendLine('        </linearGradient>').
            AppendLine('    </defs>').
            AppendLine('    <style type="text/css">').
            AppendLine('    .func_g:hover {{ stroke:black; stroke-width:0.5; cursor:pointer; }}').
            AppendLine('    </style>').
            AppendLine('    <script type="text/ecmascript">').
            AppendLine('    <![CDATA[').
            AppendLine('        var details, svg;').
            AppendLine('        function init(evt) {{ ').
            AppendLine('            details = document.getElementById("details").firstChild; ').
            AppendLine('            svg = document.getElementsByTagName("svg")[0];').
            AppendLine('            unzoom();').
            AppendLine('        }}').
            AppendLine('        function s(info) {{ details.nodeValue = "Function: " + info; }}').
            AppendLine('        function c() {{ details.nodeValue = '' ''; }}').
            AppendLine('        function find_child(parent, name, attr) {{').
            AppendLine('            var children = parent.childNodes;').
            AppendLine('            for (var i=0; i<children.length;i++) {{').
            AppendLine('                if (children[i].tagName == name)').
            AppendLine('                    return (attr != undefined) ? children[i].attributes[attr].value : children[i];').
            AppendLine('            }}').
            AppendLine('            return;').
            AppendLine('        }}').
            AppendLine('        function orig_save(e, attr, val) {{').
            AppendLine('            if (e.attributes["_orig_"+attr] != undefined) return;').
            AppendLine('            if (e.attributes[attr] == undefined) return;').
            AppendLine('            if (val == undefined) val = e.attributes[attr].value;').
            AppendLine('            e.setAttribute("_orig_"+attr, val);').
            AppendLine('        }}').
            AppendLine('        function orig_load(e, attr) {{').
            AppendLine('            if (e.attributes["_orig_"+attr] == undefined) return;').
            AppendLine('            e.attributes[attr].value = e.attributes["_orig_"+attr].value;').
            AppendLine('            e.removeAttribute("_orig_"+attr);').
            AppendLine('        }}').
            AppendLine('        function update_text(e) {{').
            AppendLine('            var r = find_child(e, "rect");').
            AppendLine('            var t = find_child(e, "text");').
            AppendLine('            var w = parseFloat(r.attributes["width"].value) -3;').
            AppendLine('            var txt = find_child(e, "title").textContent.replace(/\([^(]*\)/,"");').
            AppendLine('            t.attributes["x"].value = parseFloat(r.attributes["x"].value) +3;').
            AppendLine('            ').
            AppendLine('            // Smaller than this size won''t fit anything').
            AppendLine('            if (w < 2*12*0.59) {{').
            AppendLine('                t.textContent = "";').
            AppendLine('                return;').
            AppendLine('            }}').
            AppendLine('            ').
            AppendLine('            t.textContent = txt;').
            AppendLine('            // Fit in full text width').
            AppendLine('            if (/^ *$/.test(txt) || t.getSubStringLength(0, txt.length) < w)').
            AppendLine('                return;').
            AppendLine('            ').
            AppendLine('            for (var x=txt.length-2; x>0; x--) {{').
            AppendLine('                if (t.getSubStringLength(0, x+2) <= w) {{ ').
            AppendLine('                    t.textContent = txt.substring(0,x) + "..";').
            AppendLine('                    return;').
            AppendLine('                }}').
            AppendLine('            }}').
            AppendLine('            t.textContent = "";').
            AppendLine('        }}').
            AppendLine('        function zoom_reset(e) {{').
            AppendLine('            if (e.attributes != undefined) {{').
            AppendLine('                orig_load(e, "x");').
            AppendLine('                orig_load(e, "width");').
            AppendLine('            }}').
            AppendLine('            if (e.childNodes == undefined) return;').
            AppendLine('            for(var i=0, c=e.childNodes; i<c.length; i++) {{').
            AppendLine('                zoom_reset(c[i]);').
            AppendLine('            }}').
            AppendLine('        }}').
            AppendLine('        function zoom_child(e, x, ratio) {{').
            AppendLine('            if (e.attributes != undefined) {{').
            AppendLine('                if (e.attributes["x"] != undefined) {{').
            AppendLine('                    orig_save(e, "x");').
            AppendLine('                    e.attributes["x"].value = (parseFloat(e.attributes["x"].value) - x - 10) * ratio + 10;').
            AppendLine('                    if(e.tagName == "text") e.attributes["x"].value = find_child(e.parentNode, "rect", "x") + 3;').
            AppendLine('                }}').
            AppendLine('                if (e.attributes["width"] != undefined) {{').
            AppendLine('                    orig_save(e, "width");').
            AppendLine('                    e.attributes["width"].value = parseFloat(e.attributes["width"].value) * ratio;').
            AppendLine('                }}').
            AppendLine('            }}').
            AppendLine('            ').
            AppendLine('            if (e.childNodes == undefined) return;').
            AppendLine('            for(var i=0, c=e.childNodes; i<c.length; i++) {{').
            AppendLine('                zoom_child(c[i], x-10, ratio);').
            AppendLine('            }}').
            AppendLine('        }}').
            AppendLine('        function zoom_parent(e) {{').
            AppendLine('            if (e.attributes) {{').
            AppendLine('                if (e.attributes["x"] != undefined) {{').
            AppendLine('                    orig_save(e, "x");').
            AppendLine('                    e.attributes["x"].value = 10;').
            AppendLine('                }}').
            AppendLine('                if (e.attributes["width"] != undefined) {{').
            AppendLine('                    orig_save(e, "width");').
            AppendLine('                    e.attributes["width"].value = parseInt(svg.width.baseVal.value) - (10*2);').
            AppendLine('                }}').
            AppendLine('            }}').
            AppendLine('            if (e.childNodes == undefined) return;').
            AppendLine('            for(var i=0, c=e.childNodes; i<c.length; i++) {{').
            AppendLine('                zoom_parent(c[i]);').
            AppendLine('            }}').
            AppendLine('        }}').
            AppendLine('        function zoom(node) {{ ').
            AppendLine('            var attr = find_child(node, "rect").attributes;').
            AppendLine('            var width = parseFloat(attr["width"].value);').
            AppendLine('            var xmin = parseFloat(attr["x"].value);').
            AppendLine('            var xmax = parseFloat(xmin + width);').
            AppendLine('            var ymin = parseFloat(attr["y"].value);').
            AppendLine('            var ratio = (svg.width.baseVal.value - 2*10) / width;').
            AppendLine('            ').
            AppendLine('            // XXX: Workaround for JavaScript float issues (fix me)').
            AppendLine('            var fudge = 0.0001;').
            AppendLine('            ').
            AppendLine('            var unzoombtn = document.getElementById("unzoom");').
            AppendLine('            unzoombtn.style["opacity"] = "1.0";').
            AppendLine('            ').
            AppendLine('            var el = document.getElementsByTagName("g");').
            AppendLine('            for(var i=0;i<el.length;i++){{').
            AppendLine('                var e = el[i];').
            AppendLine('                var a = find_child(e, "rect").attributes;').
            AppendLine('                var ex = parseFloat(a["x"].value);').
            AppendLine('                var ew = parseFloat(a["width"].value);').
            AppendLine('                // Is it an ancestor').
            AppendLine('                if (0 == 0) {{').
            AppendLine('                    var upstack = parseFloat(a["y"].value) > ymin;').
            AppendLine('                }} else {{').
            AppendLine('                    var upstack = parseFloat(a["y"].value) < ymin;').
            AppendLine('                }}').
            AppendLine('                if (upstack) {{').
            AppendLine('                    // Direct ancestor').
            AppendLine('                    if (ex <= xmin && (ex+ew+fudge) >= xmax) {{').
            AppendLine('                        e.style["opacity"] = "0.5";').
            AppendLine('                        zoom_parent(e);').
            AppendLine('                        e.onclick = function(e){{unzoom(); zoom(this);}};').
            AppendLine('                        update_text(e);').
            AppendLine('                    }}').
            AppendLine('                    // not in current path').
            AppendLine('                    else').
            AppendLine('                        e.style["display"] = "none";').
            AppendLine('                }}').
            AppendLine('                // Children maybe').
            AppendLine('                else {{').
            AppendLine('                    // no common path').
            AppendLine('                    if (ex < xmin || ex + fudge >= xmax) {{').
            AppendLine('                        e.style["display"] = "none";').
            AppendLine('                    }}').
            AppendLine('                    else {{').
            AppendLine('                        zoom_child(e, xmin, ratio);').
            AppendLine('                        e.onclick = function(e){{zoom(this);}};').
            AppendLine('                        update_text(e);').
            AppendLine('                    }}').
            AppendLine('                }}').
            AppendLine('            }}').
            AppendLine('        }}').
            AppendLine('        function unzoom() {{').
            AppendLine('            var unzoombtn = document.getElementById("unzoom");').
            AppendLine('            unzoombtn.style["opacity"] = "0.0";').
            AppendLine('            ').
            AppendLine('            var el = document.getElementsByTagName("g");').
            AppendLine('            for(i=0;i<el.length;i++) {{').
            AppendLine('                el[i].style["display"] = "block";').
            AppendLine('                el[i].style["opacity"] = "1";').
            AppendLine('                zoom_reset(el[i]);').
            AppendLine('                update_text(el[i]);').
            AppendLine('            }}').
            AppendLine('        }}    ').
            AppendLine('    ]]>').
            AppendLine('    </script>').
            AppendLine('    <rect x="0.0" y="0" width="{0:0.0}" height="{1:0.0}" fill="url(#background)" />').
            ToString()
        }
        return [HotFlameGraphBuilder]::_headerTemplate
    }
}

function Export-FlameGraph {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSTracer]
        $Tracer,

        [string]
        $GraphTitle = 'Flame Graph',

        [string]
        $OutputPath,

        [switch]
        $IgnoreTimestamps
    )
    begin {
        $FunctionContextProperty = [CallStackFrame].GetProperty('FunctionContext', [BindingFlags]'NonPublic,Instance')
        $scriptBlockField = [Ref].Assembly.GetType('System.Management.Automation.Language.FunctionContext').GetField('_scriptBlock',[BindingFlags]'NonPublic,Instance')
    }
    process {
        if ([string]::IsNullOrEmpty($OutputPath)) {
            $OutputPath = Join-Path -Path $PWD -ChildPath ('flamegraph_{0}_{1:yyyyMMdd_HHmmss_fffff}.svg' -f ($GraphTitle -replace '[^a-z\d]+','_'), $Tracer.SessionStart())
        }
        if (![Path]::HasExtension($OutputPath)) {
            $OutputPath = Join-Path -Path $OutputPath -ChildPath ('flamegraph_{0}_{1:yyyyMMdd_HHmmss_fffff}.svg' -f ($GraphTitle -replace '[^a-z\d]+','_'), $Tracer.SessionStart())
        }

        $KVP = [KeyValuePair[DateTime,List[CallStackFrame]][]]::new($Tracer.Samples.Count)
        ([ICollection]$Tracer.Samples).CopyTo($KVP, 0)
        $Samples = $Tracer.Samples.Count
        $Sorted = $KVP | Sort-Object -Property Key
        
        $sortedoccurences = [SortedDictionary[[string[]], int]]::new([StringArrayComparer]::new())
        $prevKey = [string[]]@()
        $prev = [string[]]@()
        $comparer = [StringArrayComparer]::new()
        $Sorted.ForEach({
            $callstack = [CallStackFrame[]]$_.Value
            [Array]::Reverse($callstack)
            $strings = [List[string]]@()
            for ($i = 0; $i -lt $callstack.Length; $i++) {
                $csf = $callstack[$i]

                $sb = $scriptBlockField.GetValue($FunctionContextProperty.GetValue($csf))
                $ast = $sb.Ast.Find({$args[0].Extent -eq $csf.Position},$true)[0]
                $parent = $ast.Parent
                while ($null -ne $parent -and $parent -isnot [FunctionDefinitionAst] -and $parent -isnot [TypeDefinitionAst]) {
                    $parent = $parent.Parent
                }
                if ($null -eq $parent) {
                    $funcName = '<ScriptBlock>'
                    if ($strings.Where({$_ -eq $funcName},'First',1).Count -eq 0) {
                        $strings.Add($funcName)
                    }
                }
                if ($parent -is [FunctionDefinitionAst]) {
                    $funcName = $parent.Name
                    while ($null -ne $parent -and $parent -isnot [TypeDefinitionAst]) {
                        $parent = $parent.Parent
                    }
                    if ($null -eq $parent) {   
                        $namedBlock = $ast.Parent
                        while ($namedBlock -isnot [NamedBlockAst]) {
                            $namedBlock = $namedBlock.Parent
                            if ($namedBlock -is [FunctionDefinitionAst]) {
                                Write-Warning "Could not find named block for $($funcName) @ $($csf.Position)"
                                break
                            }
                        }
                        $funcName = '{0}<{1}>' -f $funcName, $namedBlock.BlockKind

                        if ($strings.Where({$_ -eq $funcName},'First',1).Count -eq 0) {
                            $strings.Add($funcName)
                        }
                    }
                }
                if ($parent -is [TypeDefinitionAst]) {
                    $funcName = $parent.Name
                    $functionMember = $ast.Parent
                    while ($functionMember -isnot [FunctionMemberAst] -and $functionMember -isnot [PropertyMemberAst]) {
                        $functionMember = $functionMember.Parent
                        if ($functionMember -is [TypeDefinitionAst]) {
                            $namestring = $ast.GetType().Name
                            while ($null -ne $ast.Parent) {
                                $ast = $ast.Parent
                                $namestring = '{0}.{1}' -f $ast.GetType().Name, $namestring
                            }
                            Write-Warning "Could not find function member for $($funcName) @ $($csf.Position) - $($namestring)"
                            break
                        }
                    }
                    $funcName = '{0}<{1}>' -f $funcName, $functionMember.Name
                    if ($strings.Where({$_ -eq $funcName},'First',1).Count -eq 0) {
                        $strings.Add($funcName)
                    }
                }

                $line = $csf.Position.Text.Split([Environment]::NewLine)
                $elipsis = if($line.Length -gt 1) { ' ...' } else { '' }
                $Source = $csf.InvocationInfo.MyCommand.Source
                if ([string]::IsNullOrEmpty($Source)) { $Source = [Path]::GetFileName([Path]::GetDirectoryName($csf.ScriptName)) }
                if ([string]::IsNullOrEmpty($Source) -and [string]::IsNullOrEmpty([Path]::GetFileName($csf.ScriptName))) {
                    $str = '{0}{1}' -f $line[0], $elipsis
                    $strings.Add($str)
                    continue
                }
                $str = '{3}{4} [{0}:{1}:{2}]' -f $Source, [Path]::GetFileName($csf.ScriptName), $csf.ScriptLineNumber, $line[0], $elipsis
                $strings.Add($str)
            }
            if (!$IgnoreTimestamps) {
                if ($comparer.Compare($prev, [string[]]$strings) -eq 0) {
                    $sortedoccurences[$prevKey] += 1
                    return
                }
                $prev = [string[]]$strings
                $strings.Insert(0,$_.Key.ToString('o'))
                $prevKey = [string[]]$strings
                $sortedoccurences.Add($prevKey, 1)
            }
            else {
                if (!$sortedoccurences.ContainsKey($strings)) {
                    $sortedoccurences.Add($strings, 0)
                }
                $sortedoccurences[$strings] += 1
            }
        })
        $stacks = [string[][]]$sortedoccurences.Keys
        $maxDepth = ($stacks.ForEach('Count') | Measure-Object -Maximum).Maximum
        
        $Bars = [List[FlameGraphBar]]@()
        $start = 5
        if ($IgnoreTimestamps) {
            $start--
        }
        for ($i = $start; $i -lt $maxDepth; $i++) {
            $x = 0
            $samplestart = 0
            $samplecount = 0
            $cursor = 0
            while ($x -lt $stacks.Count) {
                while ($i -ge $stacks[$x].Length -and $x -lt $stacks.Count) {
                    $cursor += $sortedoccurences[$stacks[$x]]
                    $x++
                }
                if ($x -ge $stacks.Count) { break }
                $title = $stacks[$x][$i]
                $samplestart = $cursor
                $samplecount = $sortedoccurences[$stacks[$x]]
                $cursor += $sortedoccurences[$stacks[$x]]
                $x++
                while ($x -lt $stacks.Count -and $stacks[$x][$i] -eq $title) {
                    if ($i -gt $start -and $stacks[$x][$i-1] -ne $stacks[$x-1][$i-1]) {
                        break
                    }
                    $samplecount += $sortedoccurences[$stacks[$x]]
                    $cursor += $sortedoccurences[$stacks[$x]]
                    $x++
                }
                $Bars.Add([FlameGraphBar]::new($title, @($samplecount, $samplestart, ($i-$start))))
                $title = $null
            }
        }
        $Graph = [HotFlameGraphBuilder]::GetFlameGraph($Bars, $samples, $GraphTitle, 1920, 1080)

        if (![Path]::IsPathRooted($OutputPath)) {
            $OutputPath = [Path]::GetFullPath($OutputPath,$PWD)
        }
        $Directory = [Path]::GetDirectoryName($OutputPath)
        if (-not [string]::IsNullOrEmpty($Directory) -and -not (Test-Path $Directory)) {
            $null = New-Item -ItemType Directory -Path $Directory -Force
        }
        [File]::WriteAllText($OutputPath, $Graph)
        Write-Verbose "Flame graph saved to $OutputPath"
    }
}

function Trace-Script {
    [CmdletBinding()]
    [OutputType([PSTracer])]
    param (
        [Parameter(ValueFromPipeline)]
        [object]
        $InputObject = $null,

        [Parameter(Mandatory, Position = 0)]
        [ScriptBlock]
        $ScriptBlock,

        [Parameter()]
        [ValidateRange(100,10000)]
        [double]
        $SampleIntervalMs = 1000
    )
    begin {
        $Tracer = [PSTracer]::new($SampleIntervalMs)
        $Flags = [BindingFlags]::Instance -bor [BindingFlags]::Static -bor [BindingFlags]::Public -bor [BindingFlags]::NonPublic
        $InvokeWithPipe = [ScriptBlock].GetMethod('InvokeWithPipe', $Flags)
        $ErrorHandlingBehavior = [Ref].Assembly.GetType('System.Management.Automation.ScriptBlock+ErrorHandlingBehavior')
        $PipeType = [Ref].Assembly.GetType('System.Management.Automation.Internal.Pipe')
        $EmptyPipeCtor = $PipeType.GetConstructor($Flags, @())
        $NullPipeProperty = $PipeType.GetProperty('NullPipe', $Flags)
        $ArrayEmptyObject = [Array].GetMethod('Empty').MakeGenericMethod([object]).Invoke($null,@())
    }
    process {
        try {
            $Pipe = $EmptyPipeCtor.Invoke(@())
            $null = $NullPipeProperty.SetValue($Pipe, $true)
            $Tracer.Start()
            $null = $InvokeWithPipe.Invoke(
                $ScriptBlock, 
                @(
                    <# useLocalScope #> $false, 
                    <# errorHandlingBehavior #> $ErrorHandlingBehavior::WriteToCurrentErrorPipe,
                    <# dollarUnder #> $InputObject,
                    <# input #> $ArrayEmptyObject,
                    <# scriptThis #> $null,
                    <# outputPipe #> $Pipe,
                    <# invocationInfo #> $null,
                    <# propagateAllExceptionsToTop #> $false,
                    <# variablesToDefine #> $null,
                    <# functionsToDefine #> $null,
                    <# args #> $null
                ))
            $Tracer.Stop()
        }
        catch [PipelineStoppedException] {
            $Tracer.Finish()
            $PSCmdlet.WriteObject($Tracer)
            throw
        }
        catch {
            $Tracer.Stop()
            Write-Warning $_.Exception.Message
        }
    }
    end {
        $Tracer.Finish()
        $PSCmdlet.WriteObject($Tracer)
    }
}

Export-ModuleMember -Function Trace-Script, Export-FlameGraph
