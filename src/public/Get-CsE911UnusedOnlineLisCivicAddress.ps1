using module '..\..\modules\PSClassExtensions\bin\release\PSClassExtensions\PSClassExtensions.psd1'

function Get-CsE911UnusedOnlineLisCivicAddress {
    [CmdletBinding()]
    [OutputType([LisCivicAddress])]
    param()
    end {
        Assert-TeamsIsConnected
        $commandHelper = [PSFunctionHost]::StartNew($PSCmdlet, 'Getting Unused Civic Addresses', [E911ModuleState]::Interval)
        try {
            [E911ModuleState]::InitializeCaches($commandHelper)
            [LisCivicAddress]::GetAll().Where({!$_.IsInUse()}) | Write-Output
        }
        finally {
            if ($null -ne $commandHelper) {
                $commandHelper.Dispose()
            }
        }
    }
}