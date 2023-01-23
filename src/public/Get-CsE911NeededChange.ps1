function Get-CsE911NeededChange {
    [CmdletBinding()]
    [OutputType([ChangeObject])]
    param (
        # Parameter help description
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSCustomObject[]]
        $LocationConfiguration,

        [switch]
        $ForceOnlineCheck
    )

    begin {
        $commandHelper = [PSFunctionHost]::StartNew($PSCmdlet, 'Getting Needed Changes', [E911ModuleState]::Interval)
        $StartingCount = [Math]::Max(0, [E911ModuleState]::MapsQueryCount)
        Assert-TeamsIsConnected
        [E911ModuleState]::ForceOnlineCheck = $ForceOnlineCheck
        # [E911ModuleState]::ShouldClear = $true
        [E911ModuleState]::InitializeCaches($commandHelper)
        $Rows = [Collections.Generic.List[E911DataRow]]@()
        $commandHelper.WriteVerbose('Validating Rows...')
        $validatingHelper = [PSFunctionHost]::StartNew($commandHelper, 'Validating Rows')
        $commandHelper.ForceUpdate('Validating Rows...')
    }
    process {
        foreach ($obj in $LocationConfiguration) {
            $lc = [E911DataRow]::new($obj)
            $validatingHelper.Update($true, $lc.RowName())
            $validatingHelper.WriteVerbose(('{0} Validating object...' -f $lc.RowName()))
            # We can no longer skip "unchanged" rows because we need to check for changes in other rows that may affect this row
            if ($lc.HasWarnings()) {
                $validatingHelper.WriteVerbose(('{0} validation failed with {1} issue{2}!' -f $lc.RowName(), $lc.Warning.Count(), $(if($lc.Warning.Count() -gt 1) {'s'})))
                [ChangeObject]::new($lc) | Write-Output
                continue
            }
            [void]$Rows.Add($lc)
        }
    }

    end {
        $validatingHelper.Complete()
        $commandHelper.WriteVerbose('Processing Rows...')
        $commandHelper.ForceUpdate('Processing Rows...')
        $processingHelper = [PSFunctionHost]::StartNew($commandHelper, 'Processing Rows')
        $processingHelper.Total = $Rows.Count
        foreach ($Row in $Rows) {
            $processingHelper.Update($true, $Row.RowName())
            if ($Row.HasWarnings()) {
                $processingHelper.WriteVerbose(('{0} validation failed with {1} issue{2}!' -f $Row.RowName(), $Row.Warning.Count(), $(if($Row.Warning.Count() -gt 1) {'s'})))
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
        $processingHelper.Complete()
        $commandHelper.Complete()
        $commandHelper.WriteVerbose(('Performed {0} Maps Queries' -f ([E911ModuleState]::MapsQueryCount - $StartingCount)))
        $commandHelper.WriteVerbose('Finished')
    }
}

