using module "..\TeamsE911Automation\src\TeamsE911Automation.psd1"

param (
    [bool]
    $Verbose = $false
)

Write-Information "Testing full end-to-end workflow via CSV..."

Write-Information ""
Write-Information "Removing existing configuration..."
Remove-CsE911Configuration -Verbose:$Verbose

Write-Information ""
Write-Information "Beginning Tests..."

$CsvPath1 = "$PSScriptRoot\test_data.csv"
Write-Information ""
Write-Information "Importing From $CsvPath1"
$RawInput1 = Import-Csv -Path $CsvPath1 -Verbose:$Verbose

Write-Information ""
Write-Information "Get-CsE911NeededChange for $CsvPath1"
$Out11 = $RawInput1 | Get-CsE911NeededChange -Verbose:$Verbose
Write-Information ""
Write-Information "$($RawInput1.Count) inputs provided to pipeline"
Write-Information "$($Out11.Where({ $_.UpdateType -eq 'Online' }).Count) Online updates needed"
Write-Information "$($Out11.Where({ $_.UpdateType -eq 'Source' }).Count) Source updates needed"

Write-Information ""
Write-Information "Set-CsE911SourceChange OutOfOrder for $CsvPath1"
$Out12 = $Out11 | Set-CsE911SourceChange -RawInput $RawInput1 -Verbose:$Verbose
Write-Information ""
Write-Information "$($Out11.Count) inputs provided to pipeline"
Write-Information "$($Out12.Count) outputs generated from pipeline"

Write-Information ""
Write-Information "Set-CsE911OnlineChange OutOfOrder for $CsvPath1"
$Out13 = $Out12 | Set-CsE911OnlineChange -Verbose:$Verbose
Write-Information ""
Write-Information "$($Out12.Count) inputs provided to pipeline"
Write-Information "$($Out13.Where({ $_.UpdateType -eq 'Online' }).Count) Online updates needed"
Write-Information "$($Out13.Where({ $_.UpdateType -eq 'Source' }).Count) Source updates needed"

Write-Information ""
Write-Information "Set-CsE911OnlineChange ProperOrder for $CsvPath1"
$Out14 = $Out11 | Set-CsE911OnlineChange -Verbose:$Verbose
Write-Information ""
Write-Information "$($Out11.Count) inputs provided to pipeline"
Write-Information "$($Out14.Where({ $_.UpdateType -eq 'Online' }).Count) Online updates needed"
Write-Information "$($Out14.Where({ $_.UpdateType -eq 'Source' }).Count) Source updates needed"

Write-Information ""
Write-Information "Set-CsE911SourceChange ProperOrder for $CsvPath1"
$Out15 = $Out14 | Set-CsE911SourceChange -RawInput $RawInput1 -Verbose:$Verbose
Write-Information ""
Write-Information "$($Out14.Count) inputs provided to pipeline"
Write-Information "$($Out15.Count) outputs generated from pipeline"

$CsvPath2 = "$PSScriptRoot\test_data_results.csv"

Write-Information ""
Write-Information "Exporting To $CsvPath2"
$Out15 | Export-Csv -Path $CsvPath2 -NoTypeInformation -Verbose:$Verbose

Write-Information ""
Write-Information "Importing From $CsvPath2"
$RawInput2 = Import-Csv -Path $CsvPath2 -Verbose:$Verbose

Write-Information ""
Write-Information "Get-CsE911NeededChange for $CsvPath2"
$Out21 = $RawInput2 | Get-CsE911NeededChange -Verbose:$Verbose
Write-Information ""
Write-Information "$($RawInput2.Count) inputs provided to pipeline"
Write-Information "$($Out21.Where({ $_.UpdateType -eq 'Online' }).Count) Online updates needed"
Write-Information "$($Out21.Where({ $_.UpdateType -eq 'Source' }).Count) Source updates needed"

Write-Information ""
Write-Information "Get-CsE911NeededChange -ForceOnlineCheck for $CsvPath2"
$Out22 = $RawInput2 | Get-CsE911NeededChange -ForceOnlineCheck -Verbose:$Verbose
Write-Information ""
Write-Information "$($RawInput2.Count) inputs provided to pipeline"
Write-Information "$($Out22.Where({ $_.UpdateType -eq 'Online' }).Count) Online updates needed"
Write-Information "$($Out22.Where({ $_.UpdateType -eq 'Source' }).Count) Source updates needed"

[PSCustomObject]@{
    CsvPath1 = $CsvPath1
    RawInput1 = $RawInput1
    GetNeededChangeOutput1 = $Out11
    SetSourceChangeOutput1OutOfOrder = $Out12
    SetOnlineChangeOutput1OutOfOrder = $Out13
    SetSourceChangeOutput1ProperOrder = $Out14
    SetOnlineChangeOutput1ProperOrder = $Out15
    CsvPath2 = $CsvPath2
    RawInput2 = $RawInput2
    GetNeededChangeOutput2 = $Out21
    GetNeededChangeOutput2ForceOnline = $Out22
}