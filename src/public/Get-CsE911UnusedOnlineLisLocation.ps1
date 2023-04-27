using module '..\..\modules\PSClassExtensions\bin\release\PSClassExtensions\PSClassExtensions.psd1'

function Get-CsE911UnusedOnlineLisLocation {
    [CmdletBinding()]
    [OutputType([LisLocation])]
    param()
    end {
        Assert-TeamsIsConnected
        $commandHelper = [PSFunctionHost]::StartNew($PSCmdlet, 'Getting Unused Locations', [E911ModuleState]::Interval)
        try {
            [E911ModuleState]::InitializeCaches($commandHelper)
            [LisLocation]::GetAll({$_.Location -and !$_.IsInUse()}) | Write-Output
        }
        finally {
            if ($null -ne $commandHelper) {
                $commandHelper.Dispose()
            }
        }
    }
}