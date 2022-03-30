using module "..\TeamsE911Automation\src\TeamsE911Automation.psd1"

param (
    [switch]
    $Verbose
)

Write-Information "Testing simplified end-to-end workflow via CSV..."

Write-Information ""
Write-Information "Removing existing configuration..."
Remove-CsE911Configuration -Verbose:$Verbose

Write-Information ""
Write-Information "Beginning Tests..."
Reset-CsE911Cache -Verbose:$Verbose

Write-Information ""
Write-Information "Running Pipeline..."
$CsvPath1 = "$PSScriptRoot\test_data.csv"
$RawInput1 = Import-Csv -Path $CsvPath1 -Verbose:$Verbose
$RawOutput1 = $RawInput1 | Get-CsE911NeededChange -Verbose:$Verbose | 
                    Set-CsE911OnlineChange -Verbose:$Verbose
# write $RawOutput1 back to source data
# $RawOutput1 | Export-Csv -Path $CsvPath1 -NoTypeInformation

Write-Information ""
Write-Information "$($RawInput1.Count) inputs provided to pipeline"
Write-Information "$($RawOutput1.Count) outputs generated from pipeline"

[PSCustomObject]@{
    CsvPath1 = $CsvPath1
    RawInput1 = $RawInput1
    RawOutput1 = $RawOutput1
}