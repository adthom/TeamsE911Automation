$BasePath = $PSScriptRoot
$SourceModuleName = "TeamsE911Automation"
$DestinationModuleName = "TeamsE911Automation"
$RootFolder = Split-Path $BasePath -Parent
$RepoFolder = Split-Path $RootFolder -Parent
$SourcePath = Join-Path -Path $RootFolder -ChildPath "modules\${SourceModuleName}\release\Scripts"
$DestinationPath = Join-Path -Path $RepoFolder -ChildPath "TeamsAdminSamples\PowerShell\${DestinationModuleName}"
$DisclaimerPath = Join-Path -Path $RootFolder -ChildPath "modules\${SourceModuleName}\build\disclaimer.txt"
$DisclaimerLength = @(Get-Content -Path $DisclaimerPath).Count
if ($null -ne $DisclaimerLength -and $DisclaimerLength -gt 0) {
    $DisclaimerLength++
}
else {
    $DisclaimerLength = 0
}

$Scripts = Get-ChildItem -Path $SourcePath -Filter *.ps1
foreach ($Script in $Scripts) {
    $Content = Get-Content -Path $Script.FullName | Select-Object -Skip $DisclaimerLength
    Set-Content -Path "$DestinationPath\$($Script.Name)" -Value $Content -Force
}