using module "..\TeamsE911Automation\src\TeamsE911Automation.psd1"

param (
    [switch]
    $Verbose
)

Write-Information "Testing simplified end-to-end workflow via CSV with Export..."

Write-Information ""
Write-Information "Removing existing configuration..."
Remove-CsE911Configuration -Verbose:$Verbose

Write-Information ""
Write-Information "Beginning Tests..."
Reset-CsE911Cache -Verbose:$Verbose

Write-Information ""
Write-Information "Configuring locations..."
$CsvPath1 = "$PSScriptRoot\test_data.csv"
$RawInput1 = Import-Csv -Path $CsvPath1 -Verbose:$Verbose
$RawOutput1 = $RawInput1 | Get-CsE911NeededChange -Verbose:$Verbose | 
                    Set-CsE911OnlineChange -Verbose:$Verbose
Write-Information ""
Write-Information "$($RawInput1.Count) inputs provided to pipeline"
Write-Information "$($RawOutput1.Count) outputs generated from pipeline"

Reset-CsE911Cache -Verbose:$Verbose
Write-Information "Exporting Configuration..."
$RawOutput2 = Get-CsE911OnlineConfiguration -Verbose:$Verbose
Write-Information ""
Write-Information "$($RawOutput2.Count) outputs generated from pipeline"

Write-Information ""
Write-Information "Removing created configuration..."
Remove-CsE911Configuration -Verbose:$Verbose

Reset-CsE911Cache -Verbose:$Verbose
Write-Information ""
Write-Information "Re-importing Configuration..."
$RawOutput3 = $RawOutput2 | Get-CsE911NeededChange -Verbose:$Verbose | 
                    Set-CsE911OnlineChange -Verbose:$Verbose
Write-Information ""
Write-Information "$($RawOutput2.Count) inputs provided to pipeline"
Write-Information "$($RawOutput3.Count) outputs generated from pipeline"

[PSCustomObject]@{
    CsvPath1 = $CsvPath1
    RawInput1 = $RawInput1
    RawOutput1 = $RawOutput1
    RawOutput2 = $RawOutput2
    RawOutput3 = $RawOutput3
}