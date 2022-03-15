param (
    [int]
    [ValidateRange(0, [int]::MaxValue)]
    $MajorVersion,

    [int]
    [ValidateRange(0, [int]::MaxValue)]
    $MinorVersion,

    [string]
    $Company,

    [string]
    $Author
)

function CleanPSFile ([string]$Path, [string]$PSScriptAnalyzerSettings) {
    $Content = Get-Content -Path $Path -Raw
    try {
        $nl = [Environment]::NewLine
        $nlr = [Regex]::Escape($nl)
        $Formatted = $Content -replace '\r?\n', $nl                             # fix mismatched line endings
        $Formatted = Invoke-Formatter -ScriptDefinition $Formatted -Settings $PSScriptAnalyzerSettings
        $Formatted = $Formatted -split $nlr -replace '\s+$', '' -join $nl       # clean up trailing whitespace
        $Formatted = $Formatted -replace "({|\()($nlr){2,}", "`$1$nl"           # clean up extra newlines after open paren/brace
        $Formatted = $Formatted -replace "($nlr){3,}", "$nl$nl"                 # clean up more than 3 newlines in a row
        $Formatted = $Formatted.TrimEnd($nl) + $nl                              # clean up more than 3 newlines in a row
        if ($Content -ne $Formatted) {
            Write-Information -MessageData "Fixing formatting for $([System.IO.Path]::GetFileName($Path))"
            Set-Content -Path $Path -Value $Formatted
        }
    }
    catch {
        Write-Warning -Message "PSScriptFormatterHadError: $($Path)"
        Write-Warning -Message $_
    }
}

function AnalyzePSFile ([string]$Path, [string]$PSScriptAnalyzerSettings) {
    CleanPSFile -Path $Path -PSScriptAnalyzerSettings $PSScriptAnalyzerSettings
    try {
        $Issues = Invoke-ScriptAnalyzer -Path $Path -Settings $PSScriptAnalyzerSettings -ErrorAction Stop
        if ($Issues.Count -gt 0) {
            Write-Warning -Message "Found $($Issues.Count) issues in $([System.IO.Path]::GetFileNameWithoutExtension($Path))"
            foreach ($i in $Issues) {
                Write-Information -MessageData "PSScriptAnalyzer - $($i.Severity.ToString().ToUpper()) - $($i.RuleName)"
                Write-Information -MessageData '    Issue Text:'
                $IssueText = $i.Extent.Text -split "`n"
                for ($j = 0; $j -lt $IssueText.Count; $j++) {
                    $index = $j + $i.Extent.StartLineNumber
                    Write-Information -MessageData "    ${index}: $($IssueText[$j])"
                }
            }
            Write-Information -MessageData ''
        }
    }
    catch {
        Write-Warning -Message "PSScriptAnalyzerHadError: $($Path) - $($_.Exception.Message)"
        Write-Warning -Message $_.Exception
    }
}

# Get Project Root Folder
$ProjectRoot = Split-Path -Path $PSScriptRoot -Parent

# Get Module Name from Project Folder Name
$ModuleName = Split-Path -Path $ProjectRoot -Leaf

# Setup Path/File Variables for use in build
$srcPath = [IO.Path]::Combine($ProjectRoot, 'src')
$releasePath = [IO.Path]::Combine($ProjectRoot, 'release', $ModuleName)
$zipPath = [IO.Path]::Combine($ProjectRoot, 'release')
$moduleFile = "${releasePath}\${ModuleName}.psm1"
$moduleManifestFile = "${releasePath}\${ModuleName}.psd1"
$srcModuleManifest = "${srcPath}\${ModuleName}.psd1"
$PSScriptAnalyzerSettings = "${ProjectRoot}\PSScriptAnalyzer.psd1"

$ModuleManifest = Import-PowerShellDataFile -Path $srcModuleManifest

if (($MajorVersion + $MinorVersion) -eq 0 -and $null -ne $ModuleManifest['ModuleVersion']) {
    $MajorVersion = [int]($ModuleManifest['ModuleVersion'] -split '\.')[0]
    if ( ($ModuleManifest['ModuleVersion'] -split '\.').Count -gt 1 ) {
        $MinorVersion = [int]($ModuleManifest['ModuleVersion'] -split '\.')[1]
    }
    $BuildNumber = [int]([datetime]::Now.ToString('yy') + [datetime]::Now.DayOfYear)
    if ( ($ModuleManifest['ModuleVersion'] -split '\.').Count -gt 2 ) {
        $CurrentBuildNumber = [int]($ModuleManifest['ModuleVersion'] -split '\.')[2]
        if ( ($ModuleManifest['ModuleVersion'] -split '\.').Count -gt 3 ) {
            $Revision = [int]($ModuleManifest['ModuleVersion'] -split '\.')[3]
        }
    }
    if ( $CurrentBuildNumber -ne $BuildNumber ) {
        $Revision = 1
    }
    else {
        $Revision++
    }
}
$Version = '{0}.{1}.{2}.{3}' -f @(
    $MajorVersion,
    $MinorVersion,
    $BuildNumber,
    $Revision
)
Update-ModuleManifest -Path $srcModuleManifest -ModuleVersion $Version
AnalyzePSFile -Path $srcModuleManifest -PSScriptAnalyzerSettings $PSScriptAnalyzerSettings

#Get public and private function definition files.
$Public = @( Get-ChildItem -Path $srcPath\Public\*.ps1 -Recurse -ErrorAction SilentlyContinue )
$Private = @( Get-ChildItem -Path $srcPath\Private\*.ps1 -Recurse -ErrorAction SilentlyContinue )
$FunctionsToExport = $Public.BaseName

$NewModuleManifestParams = @{
    Path              = $moduleManifestFile
    FunctionsToExport = $FunctionsToExport
    ModuleVersion     = $Version
    CompanyName       = $Company
    Author            = $Author
}

if ( [string]::IsNullOrEmpty($Company) -and $ModuleManifest['CompanyName'].ToLower() -ne 'unknown' ) {
    $NewModuleManifestParams['CompanyName'] = $ModuleManifest['CompanyName']
}
if ( [string]::IsNullOrEmpty($Author) ) {
    $NewModuleManifestParams['Author'] = $ModuleManifest['Author']
}

# Update properties from src Manifest
$Parameters = (Get-Command -Name Update-ModuleManifest).Parameters.Keys
foreach ( $p in $Parameters ) {
    if ( $null -ne $ModuleManifest[$p] ) {
        if ( $p -eq 'PrivateData' ) {
            foreach ( $d in $ModuleManifest['PrivateData']['PSData'].Keys ) {
                $PSData = $ModuleManifest['PrivateData']['PSData']
                if ( $null -ne $PSData[$d] ) {
                    if ( $d -in $Parameters ) {
                        $PSData.Remove($d)
                    }
                    if ( $d -notin $NewModuleManifestParams.Keys) {
                        [void] $NewModuleManifestParams.Add($d, $PSData[$d])
                    }
                }
                if ( $PSData.Keys -gt 0 ) {
                    [void] $NewModuleManifestParams.Add('PrivateData', $PSData)
                }
            }
        }
        elseif ( $p -notin $NewModuleManifestParams.Keys -and $p -notin @('Copyright') ) {
            if ( $p -ne 'FunctionsToExport' -and $p.EndsWith('ToExport') -and $ModuleManifest[$p] -eq '*' ) {
                [void] $NewModuleManifestParams.Add($p, @())
            }
            else {
                [void] $NewModuleManifestParams.Add($p, $ModuleManifest[$p])
            }
        }
    }
}

# Remove old release, copy all data from src to releasePath
if ( -not ( Test-Path -Path $releasePath -PathType Container) ) {
    New-Item -Path $releasePath -ItemType Directory | Out-Null
}

Get-ChildItem "${releasePath}/" -Recurse | Remove-Item -Recurse | Out-Null

$srcPathPattern = [Regex]::Escape($srcPath)
foreach ($srcFile in @($Public + $Private)) {
    $Visibility = if ($srcFile -in $Public) { 'PUBLIC' } else { 'PRIVATE' }
    Write-Information -MessageData "Building $Visibility function: $($srcFile.Name)"
    $targetFile = $srcFile.FullName -Replace $srcPathPattern, $releasePath
    $targetFolder = $srcFile.Directory.FullName -Replace $srcPathPattern, $releasePath
    if (!(Test-Path -Path $targetFolder)) {
        New-Item -Path $targetFolder -ItemType Directory | Out-Null
    }
    if ((Test-Path -Path $targetFile)) {
        Remove-Item -Path $targetFile -Force -ErrorAction SilentlyContinue
    }
    AnalyzePSFile -Path $srcFile.FullName -PSScriptAnalyzerSettings $PSScriptAnalyzerSettings 
    Copy-Item -Path $srcFile.FullName -Destination $targetFile
}

# Cleanup Empty Files
Get-ChildItem -Path $releasePath -Recurse -File | ForEach-Object {
    $Content = Get-Content -Path $_.FullName -Raw
    if ( [string]::IsNullOrWhiteSpace( $Content ) ) {
        Remove-Item -Path $_.FullName
        continue
    }
    # remove files with no uncommented code
    $Ast = [ScriptBlock]::Create($Content).Ast
    if ($null -eq $Ast.ParamBlock -and $null -eq $Ast.DynamicParamBlock -and $null -eq $Ast.BeginBlock -and $null -eq $Ast.ProcessBlock -and ($null -eq $Ast.EndBlock -or $Ast.EndBlock.Extent.GetType().Name -eq 'EmptyScriptExtent')) {
        Remove-Item -Path $_.FullName
    }
}

# Cleanup Empty Folders
Get-ChildItem -Path $releasePath -Recurse -Directory | ForEach-Object {
    if ($null -eq (Get-ChildItem -Path $_.FullName -File -Recurse)) {
        Remove-Item -Path $_.FullName -Recurse
    }
}

# Create psm1 for module
Set-Content -Path $moduleFile -Value "# $ModuleName"
Add-Content -Path $moduleFile -Value "# Version: $Version"
Add-Content -Path $moduleFile -Value "# $($NewModuleManifestParams['Copyright'])"
Add-Content -Path $moduleFile -Value ''


$ClassFiles = @( Get-ChildItem -Path $srcPath\classes\*.ps1 -Recurse -ErrorAction SilentlyContinue )
$Classes = [Text.StringBuilder]::new()
foreach ($ClassFile in $ClassFiles) {
    $currClass = $ClassFile | Get-Content
    foreach ($line in $currClass) {
        [void]$Classes.AppendLine($line)
    }
}
if ($Classes.Length -gt 0) {
    Add-Content -Path $moduleFile -Value '# Loading Classes'
    Add-Content -Path $moduleFile -Value ''
    Add-Content -Path $moduleFile -Value $Classes.ToString()
    Add-Content -Path $moduleFile -Value ''
}

#Get public and private function definition files.
$Public = @( Get-ChildItem -Path $releasePath\Public\*.ps1 -Recurse -ErrorAction SilentlyContinue )
$Private = @( Get-ChildItem -Path $releasePath\Private\*.ps1 -Recurse -ErrorAction SilentlyContinue )

$replacePattern = $releasePath -replace '\\', '\\'

Add-Content -Path $moduleFile -Value '# Importing Module Members'
Add-Content -Path $moduleFile -Value ''
foreach ($import in @($Private + $Public)) {
    # add the dot source for all discovered PS1 files to our psm1
    $PS1Path = $import.FullName -replace $replacePattern, ''
    Add-Content -Path $moduleFile -Value ". `"`$PSScriptRoot${PS1Path}`""
}
if (![string]::IsNullOrWhiteSpace(($AdditionalModuleChecks = Get-Content -Path "${PSScriptRoot}\modulechecks.ps1" -ErrorAction SilentlyContinue))) {
    Add-Content -Path $moduleFile -Value ''
    Add-Content -Path $moduleFile -Value $AdditionalModuleChecks
}

AnalyzePSFile -Path $moduleFile -PSScriptAnalyzerSettings $PSScriptAnalyzerSettings

# Create new module manifest with our inputs
New-ModuleManifest @NewModuleManifestParams
AnalyzePSFile -Path $moduleManifestFile -PSScriptAnalyzerSettings $PSScriptAnalyzerSettings

$Files = Get-ChildItem -Path $releasePath | Select-Object -ExpandProperty FullName
Compress-Archive -Path $Files -DestinationPath ([IO.Path]::Combine($zipPath, "$ModuleName.zip")) -CompressionLevel Optimal -Force
