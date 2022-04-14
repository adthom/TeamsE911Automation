function Reset-CsE911Cache {
    [CmdletBinding()]
    param()
    end {
        [E911ModuleState]::FlushCaches($null)
    }
}
