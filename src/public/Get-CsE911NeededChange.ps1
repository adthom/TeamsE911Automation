using module '..\..\modules\PSClassExtensions\bin\release\PSClassExtensions\PSClassExtensions.psd1'
using namespace System.Collections.Generic

function Get-CsE911NeededChange {
    [CmdletBinding()]
    [OutputType([ChangeObject])]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSCustomObject[]]
        $LocationConfiguration,

        [switch]
        $ForceOnlineCheck,

        [switch]
        $NoProgress
    )

    begin {
        try {
            if ($NoProgress) {
                $commandHelper = [PSFunctionHost]::StartNewWithoutProgress($PSCmdlet, 'Getting Needed Changes', [E911ModuleState]::Interval)
            }
            else {
                $commandHelper = [PSFunctionHost]::StartNew($PSCmdlet, 'Getting Needed Changes', [E911ModuleState]::Interval)
            }
            $StartingCount = [Math]::Max(0, [E911ModuleState]::AddressValidator.MapsQueryCount)
            Assert-TeamsIsConnected
            [E911ModuleState]::ForceOnlineCheck = $ForceOnlineCheck
            [E911ModuleState]::InitializeCaches($commandHelper)
            $Rows = [List[E911DataRow]]@()
            $commandHelper.WriteVerbose('Validating Rows...')
            $validatingHelper = [PSFunctionHost]::StartNew($commandHelper, 'Validating Rows')
            $commandHelper.ForceUpdate('Validating Rows...')
        }
        catch {
            if ($null -ne $commandHelper) {
                $commandHelper.Dispose()
            }
            throw
        }
    }
    process {
        try {
            foreach ($obj in $LocationConfiguration) {
                $lc = [E911DataRow]::new($obj)
                $validatingHelper.Update($true, $lc.RowName())
                $validatingHelper.WriteVerbose(('{0} Validating object...' -f $lc.RowName()))
                if ($lc.HasWarnings()) {
                    $validatingHelper.WriteVerbose(('{0} validation failed with {1} issue{2}!' -f $lc.RowName(), $lc.Warning.Count(), $(if ($lc.Warning.Count() -gt 1) { 's' })))
                    [ChangeObject]::new($lc) | Write-Output
                    continue
                }
                $Rows.Add($lc)
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
    end {
        try {
            if ($null -ne $validatingHelper) {
                $validatingHelper.Dispose()
            }
            $commandHelper.WriteVerbose('Processing Rows...')
            $commandHelper.ForceUpdate('Processing Rows...')
            $processingHelper = [PSFunctionHost]::StartNew($commandHelper, 'Processing Rows')
            $processingHelper.Total = $Rows.Count
            foreach ($Row in $Rows) {
                $processingHelper.Update($true, $Row.RowName())
                if ($Row.HasWarnings()) {
                    $processingHelper.WriteVerbose(('{0} validation failed with {1} issue{2}!' -f $Row.RowName(), $Row.Warning.Count(), $(if ($Row.Warning.Count() -gt 1) { 's' })))
                    [ChangeObject]::new($Row) | Write-Output
                    continue
                }
                $Commands = $Row.GetChangeCommands($processingHelper)
                foreach ($Command in $Commands) {
                    if ($Command.UpdateType -eq [UpdateType]::Online) {
                        $Command.CommandObject._commandGenerated = $true
                    }
                    $Command | Write-Output
                }
            }
            $commandHelper.WriteVerbose(('Performed {0} Maps Queries' -f ([E911ModuleState]::AddressValidator.MapsQueryCount - $StartingCount)))
            $commandHelper.WriteVerbose('Finished')
        }
        catch {
            throw
        }
        finally {
            if ($null -ne $commandHelper) {
                $commandHelper.Dispose()
            }
        }
    }
}
