function Reset-CsE911Cache {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
    param()
    end {
        if ($PSCmdlet.ShouldProcess('FlushCaches')) {
            $commandHelper = [PSFunctionHost]::StartNew($PSCmdlet, 'Resetting Caches', [E911ModuleState]::Interval)
            try {
                [E911ModuleState]::FlushCaches($commandHelper)
            }
            finally {
                if ($null -ne $commandHelper) {
                    $commandHelper.Dispose()
                }
            }
        }
    }
}