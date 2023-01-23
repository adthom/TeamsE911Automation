function Reset-CsE911Cache {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
    param()
    end {
        if ($PSCmdlet.ShouldProcess("FlushCaches")) {
            [E911ModuleState]::FlushCaches($null)
        }
    }
}
