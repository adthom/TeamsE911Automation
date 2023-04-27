using namespace System.Timers
using namespace System.Management.Automation
using namespace System.Reflection
using namespace System.Collections.Generic
using namespace System.Collections.Concurrent
using namespace System.Diagnostics.Tracing

class PSTracer : Timer {
    hidden [Debugger] $debugger
    [ConcurrentDictionary[DateTime, List[CallStackFrame]]] $Samples = @{}
    hidden [PSEventJob] $Job
    [string] $Id
    hidden [GCEventListener] $gcEventListener = $null
    
    PSTracer() : base(1000) {
        $this.Id = [Guid]::NewGuid().ToString('N')
    }

    PSTracer([double] $sampleIntervalMs) : base($sampleIntervalMs) {
        $this.Id = [Guid]::NewGuid().ToString('N')
    }

    [void] Start() {
        if ($null -ne $this.Job) { return }
        if ($null -eq $this.gcEventListener) {
            # $this.gcEventListener = [GCEventListener]::new()
        }
        $this.debugger = [PSTracer]::DebuggerProperty.GetValue([PSTracer]::GetExecutionContextFromTLSMethod.Invoke($null,@()))
        $this.Samples.Clear()

        $objectEventArgs = @{
            InputObject = $this
            EventName = 'Elapsed'
            SourceIdentifier = $this.Id
            Action = { 
                $stack = [CallStackFrame[]]($Sender.debugger.GetCallStack() | Select-Object -Skip 1)
                $Sender.Samples.TryAdd($EventArgs.SignalTime, $stack)
            }
            ErrorAction = 'Stop'
        }
        $this.AutoReset = $true
        $this.Job = Register-ObjectEvent @objectEventArgs
        $this.Enabled = $true
    }

    [void] Stop() {
        if ($null -eq $this.Job) { return }
        try {
            $this.Job.StopJob()
            $this.Job.Dispose()
            $this.Enabled = $false
            if ($null -ne $this.gcEventListener) {
                $this.gcEventListener.Disable()
                $this.gcEventListener.Dispose()
                $this.gcEventListener = $null
            }
        }
        catch {
            Write-Warning "Failed to stop event for $($this.Id): $($_.Exception.Message)"
        }
    }

    [void] Dispose() {
        $this.Stop()
        ([Timer]$this).Dispose()
    }

    hidden static [Type] $PipelineType = [Ref].Assembly.GetType('System.Management.Automation.Runspaces.LocalPipeline')
    hidden static [Type] $ExecutionContextType = [Ref].Assembly.GetType('System.Management.Automation.ExecutionContext')
    hidden static [MethodInfo] $GetExecutionContextFromTLSMethod = [PSTracer]::PipelineType.GetMethod('GetExecutionContextFromTLS',[BindingFlags]'NonPublic,Static')
    hidden static [PropertyInfo] $DebuggerProperty = [PSTracer]::ExecutionContextType.GetProperty('Debugger',[BindingFlags]'NonPublic,Instance')
}

class GCEventListener : EventListener {

    [long] $gcStart = 0l
    [ulong] $TotalEvents = 0l
    [EventSource] $eventSourceEnabled = $null

    [Dictionary[DateTime,EventWrittenEventArgs]] $events = [Dictionary[DateTime,EventWrittenEventArgs]]@{}


    [void] OnEventWritten([EventWrittenEventArgs]$eventData) {
        if ($eventData.EventName.IndexOf('GCStart') -gt -1) {
            $this.gcStart = $eventData.TimeStamp.Ticks
            $this.TotalEvents++
            return
        }
        if ($eventData.EventName.IndexOf('GCEnd') -gt -1) {
            $this.events.Add([DateTime]$eventData.TimeStamp, $eventData)
            $this.TotalEvents++
            return
        }
    }

    [void] OnEventSourceCreated([EventSource]$eventSource) {
        if ($eventSource.Name -eq 'Microsoft-Windows-DotNETRuntime') {
            $this.EnableEvents($eventSource, [EventLevel]::Informational, [EventKeywords]0x1)
            $this.eventSourceEnabled = $eventSource
        }
    }

    [void] Disable() {
        if ($null -ne $this.eventSourceEnabled) {
            $this.DisableEvents($this.eventSourceEnabled)
            $this.eventSourceEnabled = $null
        }
    }
}
