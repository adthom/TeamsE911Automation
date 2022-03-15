function FixSpacing ($inputString) {
    $Lines = $inputString -split [Environment]::NewLine
    $lastLine = $Lines[-1]
    $extraSpace = $lastLine -replace "^(\s*).*$", "`$1"
    $trimmedLines = foreach ($line in $Lines) {
        $line -replace "^$extraSpace", ""
    }
    $trimmedLines -join [Environment]::NewLine
}

$Disclaimer = @(Get-Content -Path "${PSScriptRoot}\disclaimer.txt" | ForEach-Object { "# {0}" -f $_ }) -join "$([Environment]::NewLine)"

# Get Project Root Folder
$ProjectRoot = Split-Path -Path $PSScriptRoot -Parent

# Setup Path/File Variables for use in build
$srcPath = [IO.Path]::Combine($ProjectRoot, "src")
$releasePath = [IO.Path]::Combine($ProjectRoot, "release", "Scripts")
$PSScriptAnalyzerSettings = "${ProjectRoot}\PSScriptAnalyzer.psd1"

New-Item -Path $releasePath -ItemType Directory -Force | Out-Null

# Get Module Name from Project Folder Name
$ModuleName = Split-Path -Path $ProjectRoot -Leaf

$srcModuleManifest = "${srcPath}\${ModuleName}.psd1"
$ModuleManifest = Import-PowerShellDataFile $srcModuleManifest

$RequiredModules = [Text.StringBuilder]::new()
if ($null -ne $ModuleManifest['RequiredModules']) {
    $RequiredModules.Append("#Requires -Modules ") | Out-Null
    $i = 1
    foreach ($moduleHash in $ModuleManifest['RequiredModules']) {
        if ($moduleHash -is [System.Collections.Hashtable]) {
            $hashString = "@{ " + (($moduleHash.GetEnumerator() | ForEach-Object { "$($_.Key) = '$($_.Value)'" }) -join "; ") + " }"
            $RequiredModules.Append($hashString) | Out-Null
        }
        else {
            $RequiredModules.Append($moduleHash) | Out-Null
        }
        if ($i -lt $ModuleManifest['RequiredModules'].Length) {
            $RequiredModules.Append(",") | Out-Null
        }
        $i++
    }
}
$RequiredModulesText = $RequiredModules.ToString()

$ClassFiles = Get-ChildItem -Path ([IO.Path]::Combine($srcPath, "classes")) -Filter *.ps1 -File -ErrorAction SilentlyContinue
$Classes = [Text.StringBuilder]::new()
foreach ($ClassFile in $ClassFiles) {
    $currClass = $ClassFile | Get-Content
    foreach ($line in $currClass) {
        [void]$Classes.AppendLine($line)
    }
}
# # HACK: functions used in classes not currently working, manually adding for now
# $ClassFunctions = Get-ChildItem -Path ([IO.Path]::Combine($srcPath, "private")) -Filter ConvertFrom*HashTable*.ps1 -File
# foreach ($ClassFunction in $ClassFunctions) {
#     $currClass = $ClassFunction | Get-Content
#     foreach ($line in $currClass) {
#         [void]$Classes.AppendLine($line)
#     }
# }

foreach ($ClassFile in $ClassFiles) {
    try {
        . $ClassFile.FullName
    }
    catch {
        Write-Error -Message "Failed to classes $($ClassFile.FullName): $_"
    }
}

# Import all functions into current session
$Privates = Get-ChildItem -Path ([IO.Path]::Combine($srcPath, "private")) -Filter *.ps1 -File
$Publics = Get-ChildItem -Path ([IO.Path]::Combine($srcPath, "public")) -Filter *.ps1 -File
foreach ($import in @($Publics + $Privates)) {
    try {
        . $import.FullName
    }
    catch {
        Write-Error -Message "Failed to import function $($import.FullName): $_"
    }
}

# import getUsedLocalFunctions function
$GetUsedLocalFunctionsPath = "${PSScriptRoot}\GetUsedLocalFunctions.ps1"
if ((Test-Path -Path $GetUsedLocalFunctionsPath)) {
    . $GetUsedLocalFunctionsPath
}
$GetUsedLocalFunctions = Get-ChildItem -Path Function:GetUsedLocalFunctions -ErrorAction SilentlyContinue
if ($null -eq $GetUsedLocalFunctions) {
    Write-Error "Required function GetUsedLocalFunctions cannot be found!"
}

# cleanup removed old builds
Get-ChildItem -Path $releasePath -Filter *.ps1 -ErrorAction SilentlyContinue | Where-Object { $_ -notin $Publics } | Remove-Item -Force -ErrorAction SilentlyContinue

foreach ($file in $Publics) {
    $FunctionName = [IO.Path]::GetFileNameWithoutExtension($file.Name)
    $Function = Get-ChildItem -Path "Function:$FunctionName" -ErrorAction SilentlyContinue
    $ScriptBlock = $Function.ScriptBlock
    if ($null -eq $ScriptBlock) {
        Write-Warning "$FunctionName has no scriptblock!"
        continue
    }
    else {
        Write-Host "Building Script for $FunctionName"
    }
    $UsedFunctionStrings = GetUsedLocalFunctions -Script $ScriptBlock -Functions $null -GetStrings $true

    $FunctionDefinitionPredicate = {
        param([System.Management.Automation.Language.Ast]$Ast)
        $returnValue = $false
        if ($Ast -is [System.Management.Automation.Language.FunctionDefinitionAst]) {
            $returnValue = $true
        }
        $returnValue
    }
    $functionDefinition = $Function.ScriptBlock.Ast.Find($FunctionDefinitionPredicate, $true)
    if ($null -eq $functionDefinition) {
        Write-Warning "$FunctionName is not a valid PowerShell function! Skipping..."
        continue
    }

    if ($null -ne $helpAst) {
        $helpContent = $helpAst.GetHelpContent()
    }
    if ($null -ne $helpContent) {
        $helpCommentBlock = $helpContent.GetCommentBlock()
    }
    if (![string]::IsNullOrEmpty($helpCommentBlock)) {
        $helpText = $helpCommentBlock.Trim()
    }
    else {
        $helpText = ""
    }

    $CmdletBindingPredicate = {
        param([System.Management.Automation.Language.Ast]$Ast)
        $returnValue = $false
        if ($Ast -is [System.Management.Automation.Language.AttributeAst]) {
            $attribAst = [System.Management.Automation.Language.AttributeAst]$Ast
            if ($attribAst.TypeName.FullName -eq 'CmdletBinding') {
                $returnValue = $true
            }
        }
        $returnValue
    }
    $cmdletBindingDefinition = $Function.ScriptBlock.Ast.Find($CmdletBindingPredicate, $true)
    if ($null -ne $cmdletBindingDefinition) {
        $CmdletBindingText = $cmdletBindingDefinition.Extent.Text.Trim()
    }
    else {
        $CmdletBindingText = ""
    }

    $ParamBlockPredicate = {
        param([System.Management.Automation.Language.Ast]$Ast)
        $returnValue = $false
        if ($Ast -is [System.Management.Automation.Language.ParamBlockAst]) {
            $returnValue = $true
        }
        $returnValue
    }
    $paramBlockDefinition = $Function.ScriptBlock.Ast.Find($ParamBlockPredicate, $true)
    if ($null -ne $paramBlockDefinition) {
        $params = $paramBlockDefinition.Extent.Text.Trim()
    }
    else {
        $params = ""
    }

    $NamedBlockPredicate = {
        param([System.Management.Automation.Language.Ast]$Ast)
        $returnValue = $false
        if ($Ast -is [System.Management.Automation.Language.NamedBlockAst]) {
            $returnValue = $true
        }
        $returnValue
    }
    $namedBlockDefinitions = @($Function.ScriptBlock.Ast.FindAll($NamedBlockPredicate, $true) | Where-Object { $_.Parent.Parent -eq $Function.ScriptBlock.Ast })
    
    $Content = [System.Text.StringBuilder]::new()
    foreach ($namedBlock in $namedBlockDefinitions) {
        foreach ($statement in $namedBlock.Statements) {
            $blockText = FixSpacing $statement.Extent.Text.Trim()
            if (![string]::IsNullOrEmpty($blockText)) {
                $Content.AppendLine($blockText) | Out-Null
                $Content.AppendLine() | Out-Null
            }
        }
    }
    $functionText = $Content.ToString().Trim()

    if (![string]::IsNullOrEmpty($helpText)) {
        $helpText = FixSpacing $helpText
    }
    if (![string]::IsNullOrEmpty($params)) {
        $params = FixSpacing $params
    }
    $functionText = FixSpacing $functionText

    $scriptSB = [System.Text.StringBuilder]::new()
    if (![string]::IsNullOrEmpty($Disclaimer)) {
        $scriptSB.AppendLine($Disclaimer) | Out-Null
        $scriptSB.AppendLine() | Out-Null
    }
    if (![string]::IsNullOrEmpty($RequiredModulesText)) {
        $scriptSB.AppendLine($RequiredModulesText) | Out-Null
        $scriptSB.AppendLine() | Out-Null
    }
    if (![string]::IsNullOrEmpty($helpText)) {
        $scriptSB.AppendLine($helpText) | Out-Null
        $scriptSB.AppendLine() | Out-Null
    }
    if (![string]::IsNullOrEmpty($CmdletBindingText)) {
        $scriptSB.AppendLine($CmdletBindingText) | Out-Null
        $scriptSB.AppendLine() | Out-Null
    }
    if (![string]::IsNullOrEmpty($params)) {
        $scriptSB.AppendLine($params) | Out-Null
        $scriptSB.AppendLine() | Out-Null
    }
    if (![string]::IsNullOrEmpty($Classes.ToString())) {
        $scriptSB.AppendLine($Classes.ToString()) | Out-Null
        $scriptSB.AppendLine() | Out-Null
    }
    if (![string]::IsNullOrEmpty($UsedFunctionStrings)) {
        foreach ($UsedFunction in $UsedFunctionStrings) {
            $scriptSB.AppendLine($UsedFunction) | Out-Null
            $scriptSB.AppendLine() | Out-Null
        }
    }
    if (![string]::IsNullOrEmpty($functionText)) {
        $scriptSB.AppendLine($functionText.Trim()) | Out-Null
    }
    $compiledScript = $scriptSB.ToString()

    $nlr = [Regex]::Escape([Environment]::NewLine)
    $compiledScript = $compiledScript -replace "$nlr{3,}", "$([Environment]::NewLine)$([Environment]::NewLine)"
    $compiledScript = Invoke-Formatter -ScriptDefinition $compiledScript -Settings $PSScriptAnalyzerSettings

    New-Variable -Name tokens -Force | Out-Null
    New-Variable -Name errors -Force | Out-Null
    [System.Management.Automation.Language.Parser]::ParseInput($compiledScript, [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors.Count -eq 0) {
        $Issues = Invoke-ScriptAnalyzer -ScriptDefinition $compiledScript -Settings $PSScriptAnalyzerSettings
        if ($Issues.Count -gt 0) {
            Write-Warning -Message "Found $($Issues.Count) issues in $($srcFile.BaseName)"
        }
        if (!(Test-Path -Path $releasePath)) {
            New-Item -Path $releasePath -ItemType Directory | Out-Null
        }
        Set-Content -Path ([IO.Path]::Combine($releasePath, $file.Name)) -Value $compiledScript
    }
    else {
        Write-Warning "$FunctionName compiled with warnings!, not saving file"
        foreach ($e in $errors) {
            Write-Warning "$($e.ErrorId): $($e.Message) - $($e.Extent.Text)"
        }
    }
}

# create Zip Package
$Scripts = Get-ChildItem -Path $releasePath -Filter *.ps1 | Select-Object -ExpandProperty FullName
Compress-Archive -Path $Scripts -DestinationPath ([IO.Path]::Combine($releasePath, "Scripts.zip")) -CompressionLevel Optimal -Force
