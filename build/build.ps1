using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.Management.Automation
using namespace System.Management.Automation.Language
using namespace System.Text
using namespace Microsoft.PowerShell.Commands

[CmdletBinding()]
param (
    [Parameter()]
    [ValidateSet('Debug', 'Release')]
    [string]
    $BuildType = 'Release',

    [switch]
    $Clean,

    [string]
    $ModuleRoot = '',

    [switch]
    $Nested
)

if ([string]::IsNullOrEmpty($ModuleRoot)) {
    $ModuleRoot = (Get-Item $PSScriptRoot).Parent.FullName
}

$ModuleName = (Get-Item $ModuleRoot).Name
Write-Host "Building $(if($Nested){'Nested '}else{''})Module '$ModuleName'..."
$rootManifest = [IO.Path]::Combine($ModuleRoot, 'manifest.psd1')
$srcModulesPath = [IO.Path]::Combine($ModuleRoot, 'modules')
$srcAssembliesPath = [IO.Path]::Combine($ModuleRoot, 'assemblies')
$srcPath = [IO.Path]::Combine($ModuleRoot, 'src')
$binRoot = [IO.Path]::Combine($ModuleRoot, 'bin')
$releaseRoot = [IO.Path]::Combine($binRoot, ($BuildType.ToLower()))
$releasePath = [IO.Path]::Combine($releaseRoot, $ModuleName)
$releaseModulesPath = [IO.Path]::Combine($releasePath, 'modules')
$releaseAssembliesPath = [IO.Path]::Combine($releasePath, 'assemblies')
$moduleManifest = [IO.Path]::Combine($releasePath, "$ModuleName.psd1")
$moduleDefinition = [IO.Path]::Combine($releasePath, "$ModuleName.psm1")
$bldMeta = [IO.Path]::Combine($binRoot, '.bldmeta.psd1')
$zipPath = [IO.Path]::Combine($releaseRoot)
$formattingRulesPath = [IO.Path]::Combine($ModuleRoot, 'PSScriptAnalyzerFormattingRules.psd1')

# RootModule
if (!(Test-Path $rootManifest)) {
    Write-Warning "No root manifest found, please created one at $rootManifest"
    Write-Warning 'You can do this with New-ModuleManifest'
    Write-Warning 'Exiting...'
    throw 'Build Failed'
}

$Manifest = Import-PowerShellDataFile $rootManifest
$allFiles = Get-ChildItem -Path $srcPath -File -Recurse
$buildFiles = Get-ChildItem $PSScriptRoot -File -Recurse
$hashFiles = [List[string]]@($rootManifest)
foreach ($file in $allFiles) { $null = $hashFiles.Add($file.FullName) }
foreach ($file in $buildFiles) { $null = $hashFiles.Add($file.FullName) }

# check to see what needs to be re-built
$buildMetadata = Get-ChildItem -Path $bldMeta -ErrorAction SilentlyContinue
if ($null -ne $buildMetadata) {
    try {
        $buildHashes = Import-PowerShellDataFile -Path $buildMetadata.FullName -ErrorAction Stop
    }
    catch {
        Write-Warning $_.Exception.Message
        $buildHashes = $null
    }
}
if ($null -eq $buildHashes) {
    $buildHashes = @{}
}

$buildVersionKey = '__BUILD_VERSION__'
$buildNumberKey = '__BUILD_NUMBER__'
if ($null -eq $buildHashes[$BuildType]) {
    $buildHashes[$BuildType] = @{}
}
$lastVersion = $buildHashes[$BuildType][$buildVersionKey]
$lastBuild = $buildHashes[$BuildType][$buildNumberKey]

$rebuild = $Clean -or $null -eq $lastVersion -or $null -eq $lastBuild
$uncheckedFiles = [HashSet[string]]@([string[]]($buildHashes[$BuildType].Keys))
$null = $uncheckedFiles.Remove($buildVersionKey)
$null = $uncheckedFiles.Remove($buildNumberKey)
$hashFiles | ForEach-Object {
    $fileHash = (Get-FileHash -Path $_ -Algorithm SHA1).Hash
    $relPath = [IO.Path]::GetRelativePath($srcPath, $_)
    $rebuild = $rebuild -or !$buildHashes[$BuildType].ContainsKey($relPath) -or $buildHashes[$BuildType][$relPath] -ne $fileHash
    $buildHashes[$BuildType][$relPath] = $fileHash
    $null = $uncheckedFiles.Remove($relPath)
}
if ($uncheckedFiles.Count -gt 0) {
    $rebuild = $true
    $uncheckedFiles | ForEach-Object { $null = $buildHashes[$BuildType].Remove($_) }
}

$StringCompName = 'StringIEqualityComparer' + ([Guid]::NewGuid().ToString() -replace '-', '')
$StrCompDef = @"
class $StringCompName : IEqualityComparer[string] {
    [bool] Equals([string] `$x, [string] `$y) {
        return `$x.Equals(`$y, [StringComparison]::OrdinalIgnoreCase)
    }
    
    [int] GetHashCode([string] `$obj) {
        return `$obj.GetHashCode()
    }
}
"@
. ([ScriptBlock]::Create($StrCompDef))
$Comp = New-Object $StringCompName

$RequiredModules = [HashSet[ModuleSpecification]]::new()
$NestedModulesString = [HashSet[string]]@($Comp)
$NestedModules = [Dictionary[string, ModuleSpecification]]@{}
$ModulesToCopy = [List[string]]@()
if ((Test-Path $srcModulesPath)) {
    Write-Host 'Building nested modules...'
    Get-ChildItem -Path $srcModulesPath -Directory | ForEach-Object {
        $depModule = $_.BaseName
        $depModulePath = $_.FullName
        $buildCmd = "$depModulePath\build\build.ps1"
        if (!(Test-Path $buildCmd)) {
            $buildCmd = "$PSScriptRoot\build.ps1"
        }
        $updated = & $buildCmd -BuildType $BuildType -Clean:$Clean -ModuleRoot $depModulePath -Nested
        $rebuild = $rebuild -or $updated
        $builtPath = $depModulePath + '\bin\' + $BuildType + '\' + $depModule
        # store the path to replace in the manifest
        $relativeTarget = [IO.Path]::GetRelativePath($releasePath, $releaseModulesPath)
        $depModule = [IO.Path]::Combine($relativeTarget, $depModule)
        $null = $NestedModulesString.Add($_.BaseName)
        $null = $NestedModulesString.Add($depModule)
        $NestedModules[$depModule] = [ModuleSpecification]$depModule
        $null = $RequiredModules.Add($NestedModules[$depModule])
        $null = $ModulesToCopy.Add($builtPath)
    }
}

$RequiredAssemblies = [HashSet[string]]::new($Comp)
$NestedAssemblies = [Dictionary[string, string]]@{}
$AssembliesToCopy = [List[string]]@()
if ((Test-Path $srcAssembliesPath)) {
    Get-ChildItem -Path $srcAssembliesPath -File -Recurse | ForEach-Object {
        $relPath = [IO.Path]::GetRelativePath($srcAssembliesPath, $_.FullName)
        $NestedAssemblies[$_.BaseName] = $relPath
        $null = $AssembliesToCopy.Add($_.FullName)
        $RequiredAssemblies.Add($relPath)
    }
}

if (!$rebuild) {
    Write-Host 'No build needed...'
    if ($Nested) { return $false }
    return
}

foreach ($buildFile in $buildFiles) {
    if (($ext = [IO.Path]::GetExtension($buildFile)) -notin @('.ps1', '.psm1', '.psd1')) { continue }
    if ([IO.Path]::GetFileName($buildFile) -eq 'build.ps1' -and [IO.Path]::GetDirectoryName($buildFile) -eq $PSScriptRoot) { continue }
    if ((Test-Path -Path $formattingRulesPath)) {
        $originalText = [IO.File]::ReadAllText($buildFile.FullName) -replace '(\r?\n)+$', ''
        $newText = Invoke-Formatter -ScriptDefinition $originalText -Settings $formattingRulesPath
        if ($newText -ne $originalText) {
            if ([string]::IsNullOrWhiteSpace($newText)) {
                throw 'Formatter returned empty text'
            }
            [IO.File]::WriteAllText($buildFile.FullName, $newText)
        }
    }
    if ($ext -eq '.psd1') {
        $name = [IO.Path]::GetFileNameWithoutExtension($buildFile)
        if ((Get-Module -Name $name)) {
            $null = Remove-Module -Name $name
        }
        $null = Import-Module $buildFile
        continue
    }
    if ($ext -eq '.psm1') {
        $psd1 = $buildFile -replace '\.psm1$', '.psd1'
        if ((Test-Path $psd1)) {
            continue
        }
        $name = [IO.Path]::GetFileNameWithoutExtension($buildFile)
        if ((Get-Module -Name $name)) {
            $null = Remove-Module -Name $name
        }
        $null = Import-Module $buildFile.FullName
    }
    
    $rel = [IO.Path]::GetRelativePath($PSScriptRoot, $buildFile)
    $parent = [IO.Path]::GetDirectoryName($rel)
    $pathParts = $parent.Split([IO.Path]::DirectorySeparatorChar)
    $i = $pathParts.Length - 1
    $shouldDotSource = $true
    while ($i -ge 0) {
        $parent = $pathParts[0..$i] -join [IO.Path]::DirectorySeparatorChar
        $parentName = $pathParts[$i]
        if ((Test-Path ([IO.Path]::Combine($PSScriptRoot,[IO.Path]::Combine($parent, "$parentName.psd1")))) -or (Test-Path ([IO.Path]::Combine($PSScriptRoot,[IO.Path]::Combine($parent, "$parentName.psm1"))))) {
            $shouldDotSource = $false
            break
        }
        $i--
    }
    if ($shouldDotSource) {
        $null = . $buildFile
    }
}

$Manifest.RootModule = [IO.Path]::GetRelativePath($releasePath, $moduleDefinition)
$CurrentManifestVersion = $Manifest.ModuleVersion.Split('.')
if ($null -eq $lastVersion) { $lastVersion = '0.0' }
$lastVersion = $lastVersion.Split('.')
$lastBuild = [int]$lastBuild
$BuildDay = '{0:yy}{1:000}' -f [DateTime]::UtcNow, [DateTime]::UtcNow.DayOfYear
$sameVersion = $CurrentManifestVersion[0] -eq $lastVersion[0] -and $CurrentManifestVersion[1] -eq $lastVersion[1] -and $BuildDay -eq $lastVersion[2]
if (!$sameVersion) {
    $lastBuild = -1
}
$buildHashes[$BuildType][$buildVersionKey] = '{0}.{1}.{2}' -f ($CurrentManifestVersion[0, 1] + $BuildDay)
$buildHashes[$BuildType][$buildNumberKey] = ++$lastBuild
$Manifest.ModuleVersion = '{0}.{1}' -f $buildHashes[$BuildType][$buildVersionKey], $buildHashes[$BuildType][$buildNumberKey]

# Requires statements must be unique and preceed all
$PowerShellVersion = $null
$CompatiblePSEditions = [HashSet[string]]::new([string[]]@('Desktop', 'Core'), $Comp)

# using statements must be unique and first non-commented statements
$usingStatements = [HashSet[string]]::new($Comp)
# class definitions must be unique, but can appear anywhere, need to order them for loading in Windows PowerShell
$typeDeclarations = [HashSet[string]]::new($Comp)
$OtherDefinitions = [List[string]]@()
$OtherFiles = [HashSet[string]]@()

$publicFunctions = [HashSet[string]]::new($Comp)
$privateFunctions = [HashSet[string]]::new($Comp)
$publicClasses = [HashSet[string]]::new($Comp)

$moduleBodySb = [StringBuilder]::new()
foreach ($file in $allFiles) {
    $relName = [IO.Path]::GetRelativePath($srcPath, $file.FullName)
    if ($file.Extension -ne '.ps1') {
        if ($file.Extension -notin @('.psd1', '.psm1')) {
            Write-Warning "Directly Copying ${relName}..."
            $null = $OtherFiles.Add($file.FullName)
            continue
        }
        Write-Warning "Skipping processing ${relName}..."
        continue
    }
    $isPublic = $relName.TrimStart('.').TrimStart([IO.Path]::DirectorySeparatorChar).StartsWith('public')
    $content = [IO.File]::ReadAllText($file.FullName) -replace '(\r?\n)+$', ''
    $parseerrors = $null
    $ast = [Parser]::ParseInput($content, [ref]$null, [ref] $parseerrors)
    
    if ($parseerrors.Count -gt 0) {
        if ($parseerrors.Where({ $_.ErrorId -eq 'TypeNotFound' }).Count -ne $parseerrors.Count) {
            Write-Warning "Could not parse '$relname'"
            foreach ($e in $parseerrors) {
                $msg = '[{0}] ''{1}...'': {2}' -f $e.Extent.StartLineNumber, $e.Extent.Text.Substring(0, [Math]::Min($e.Extent.Text.Length, 20)), $e.Message
                Write-Warning $msg
                Write-Host ($e | ConvertTo-Json -Depth 10 -Compress)
            }
            Write-Warning 'Exiting...'
            throw 'Build Failed'
        }
        # Write-Warning "Only dependency issues found, Attempting to continue..."
        # $DependentTypes = $parseerrors.Where({$_.ErrorId -eq 'TypeNotFound'}).ForEach({$_.Extent.Text}) | Sort-Object -Unique
        # Write-Warning "Dependency Errors in ${relName}:"
        # foreach ($dependency in $DependentTypes) {
        #     Write-Warning "    [$dependency]"
        # }
    }
    if ((Test-Path -Path $formattingRulesPath)) {
        $newText = Invoke-Formatter -ScriptDefinition $content -Settings $formattingRulesPath
        if ($newText -ne $content) {
            if ([string]::IsNullOrWhiteSpace($newText)) {
                throw 'Formatter returned empty text'
            }
            Write-Warning "Formatting ${relName}..."
            [IO.File]::WriteAllText($file.FullName, $newText)
            $ast = [Parser]::ParseInput($newText, [ref]$null, [ref] $parseerrors)
        }
    }
    if ($null -ne $ast.BeginBlock -or $null -ne $ast.ProcessBlock -or $null -ne $ast.ParamBlock -or $null -ne $ast.DynamicParamBlock -or $null -ne $ast.CleanBlock) {
        Write-Warning "${relName}: Invalid PS Module File Type, only EndBlock is supported"
        Write-Warning 'Exiting...'
        throw 'Build Failed'
    }
    if ($null -ne $ast.ScriptRequirements) {
        if (![string]::IsNullOrEmpty($ast.RequiredApplicationId)) {
            Write-Warning "${relName}: '#Requires -ApplicationId' not supported"
            Write-Warning 'Exiting...'
            throw 'Build Failed'
        }
        if ($ast.RequiresPSSnapIns.Count -gt 0) {
            Write-Warning "${relName}: '#Requires -PSSnapIn' not supported"
            Write-Warning 'Exiting...'
            throw 'Build Failed'
        }
        if ($ast.ScriptRequirements.IsElevationRequired -eq $true) {
            Write-Warning "${relName}: '#Requires -RunAs' not supported"
            Write-Warning 'Exiting...'
            throw 'Build Failed'
        }
        foreach ($module in $ast.ScriptRequirements.RequiredModules) {
            $name = [IO.Path]::GetDirectoryName($module.Name)
            $filename = [IO.Path]::GetFileNameWithoutExtension($module.Name)
            if ([string]::IsNullOrEmpty($name)) {
                $name = $filename
            }
            if ($NestedModules.ContainsKey($name) -or $NestedModulesString.Contains($name)) {
                continue
            }
            $null = $RequiredModules.Add($module)
        }
        foreach ($assembly in $ast.ScriptRequirements.RequiredAssemblies) {
            $assemblyName = [IO.Path]::GetFileNameWithoutExtension($assembly)
            if ($NestedAssemblies.ContainsKey($assemblyName)) {
                continue
            }
            $null = $RequiredAssemblies.Add($assembly)
        }
        if ($ast.ScriptRequirements.RequiredPSEditions.Count -gt 0 -and $ast.ScriptRequirements.RequiredPSEditions.Count -lt $CompatiblePSEditions) {
            $null = $CompatiblePSEditions.IntersectWith($ast.ScriptRequirements.RequiredPSEditions)
            if ($CompatiblePSEditions.Count -eq 0) {
                Write-Warning "${relName}: '#Requires -PSEdition' in conflict with other requirements"
                Write-Warning 'Exiting...'
                throw 'Build Failed'
            }
        }
        if ($null -ne $ast.ScriptRequirements.RequiredPSVersion) {
            if ($null -eq $PowerShellVersion -or $ast.ScriptRequirements.RequiredPSVersion -gt $PowerShellVersion) {
                $PowerShellVersion = $ast.ScriptRequirements.RequiredPSVersion
            }
        }
    }
    foreach ($using in $ast.UsingStatements) {
        $name = $using.Name.Value
        if ($null -ne $name -and $using.UsingStatementKind -ne [UsingStatementKind]::Namespace) {
            if ($name.IndexOf('\') -gt -1 -or $name.IndexOf('/') -gt -1) {
                # resolve relative path
                $name = [IO.Path]::GetFullPath([IO.Path]::Combine([IO.Path]::GetDirectoryName($file.FullName), $name))
            }
            $relToAssemblies = [IO.Path]::GetRelativePath($srcAssembliesPath, $name)
            $relToModules = [IO.Path]::GetRelativePath($srcModulesPath, $name)
            if ($relToAssemblies.Length -lt $relToModules.Length) {
                $parent = [IO.Path]::GetDirectoryName($name)
                $fileName = [IO.Path]::GetFileName($name)
                $relative = [IO.Path]::GetRelativePath($srcAssembliesPath, $parent)
                $newPath = [IO.Path]::GetRelativePath($releasePath, [IO.Path]::Combine($releaseAssembliesPath, $relative))
                $name = [IO.Path]::Combine($newPath, $fileName)
            }
            else {
                $fileName = [IO.Path]::GetFileNameWithoutExtension($name)
                $relativeTarget = [IO.Path]::GetRelativePath($releasePath, $releaseModulesPath)
                $name = [IO.Path]::Combine($relativeTarget, $fileName)
            }
            if ($using.UsingStatementKind -eq [UsingStatementKind]::Module) {
                $mName = [IO.Path]::GetFileNameWithoutExtension($name)
                if (!$NestedModulesString.Contains($mName)) {
                    Write-Warning "${relName}: Nested Module '$mName' not found"
                }
            }
        }
        elseif ($using.UsingStatementKind -eq [UsingStatementKind]::Module) {
            $spec = [ScriptBlock]::Create($using.ModuleSpecification.Extent.Text).Invoke()
            if ($NestedModules.ContainsKey($spec.ModuleName)) {
                $spec = $NestedModules[$spec.ModuleName]
            }
            $moduleSb = [StringBuilder]::new()
            ItemToString $spec -sb $moduleSb -Compress
            $name = $moduleSb.ToString()
            $spec = [ScriptBlock]::Create($name).Invoke()
            if (!$NestedModules.ContainsKey($spec.Name)) {
                $null = $RequiredModules.Add($spec)
                $NestedModules[$spec.Name] = $spec
            }
        }
        if ($using.UsingStatementKind -eq [UsingStatementKind]::Assembly) {
            if (!$RequiredAssemblies.Contains([IO.Path]::GetFileNameWithoutExtension($name))) {
                $null = $RequiredAssemblies.Add($name)
            }
        }
        if ($null -eq $name) {
            Write-Warning "${relName}: Unable to parse using statement: $($using.Extent.Text)"
            Write-Warning 'Exiting...'
            throw 'Build Failed'
        }
        $stmt = 'using {0} {1}' -f $using.UsingStatementKind.ToString().ToLower(), $name
        $null = $usingStatements.Add($stmt)
    }
    foreach ($statement in $ast.EndBlock.Statements) {
        if ($statement -is [TypeDefinitionAst]) {
            $null = $typeDeclarations.Add($statement.Extent.Text.Trim())
            if ($statement.IsClass -and $isPublic) {
                $null = $publicClasses.Add($statement.Name)
            }
            continue
        }
        $OtherDefinitions.Add($statement.Extent.Text.Trim())
        if ($statement -is [FunctionDefinitionAst] -and $isPublic) {
            $null = $publicFunctions.Add($statement.Name)
        }
        elseif ($statement -is [FunctionDefinitionAst]) {
            $null = $privateFunctions.Add($statement.Name)
        }
    }
}

# clean the release folder
if ((Test-Path $releasePath)) {
    $null = Remove-Item -Path $releasePath -Recurse -Force -Confirm:$false -ErrorAction Stop
}

$first = $true
$usingStatements = $usingStatements | SortUsings
foreach ($using in $usingStatements) {
    $null = $moduleBodySb.AppendLine($using)
    $first = $false
}
if (!$first) { $null = $moduleBodySb.AppendLine() }

#TODO: order our type declarations to avoid issues in WindowsPowerShell...
$first = $true
foreach ($typeDec in $typeDeclarations) {
    if (!$first) { $null = $moduleBodySb.AppendLine() }
    $null = $moduleBodySb.AppendLine($typeDec)
    $first = $false
}
if (!$first) { $null = $moduleBodySb.AppendLine() }

$first = $true
foreach ($statement in $OtherDefinitions) {
    if (!$first) { $null = $moduleBodySb.AppendLine() }
    $null = $moduleBodySb.AppendLine($statement)
    $first = $false
}
if (!$first) { $null = $moduleBodySb.AppendLine() }

if ($BuildType -eq 'Debug') {
    foreach ($private in $privateFunctions) {
        $null = $publicFunctions.Add($private)
    }
}
$Manifest.FunctionsToExport = [string[]]$publicFunctions

if ($NestedModules.Count -gt 0) {
    if ($null -eq $Manifest.ScriptsToProcess) {
        $Manifest.ScriptsToProcess = @()
    }
    $importScriptPath = [IO.Path]::Combine($releaseModulesPath, 'ImportNestedModules.ps1')

    $importScriptSb = [StringBuilder]::new()
    foreach ($key in $NestedModules.Keys) {
        $spec = $NestedModules[$key]
        # get the psd1 file name if it exists
        
        $sourceModule = $ModulesToCopy.Where({$_.IndexOf($spec.Name) -gt -1})[0]
        $currentModule = [IO.Path]::GetFileNameWithoutExtension($sourceModule)
        $currentDir = [IO.Path]::Combine([IO.Path]::GetDirectoryName($sourceModule), $currentModule)
        $currentPsd1 = [IO.Path]::Combine($currentDir, $currentModule + '.psd1')
        $currentPsm1 = [IO.Path]::Combine($currentDir, $currentModule + '.psm1')
        $ModulePath = if ((Test-Path $currentPsd1)) {
            [IO.Path]::GetRelativePath($releaseModulesPath, [IO.Path]::Combine($releaseModulesPath, $currentModule, $currentModule + '.psd1'))
        }
        elseif ((Test-Path $currentPsm1)) {
            [IO.Path]::GetRelativePath($releaseModulesPath,[IO.Path]::Combine($releaseModulesPath, $currentModule, $currentModule + '.psm1'))
        }
        else {
            $spec.Name
        }
        $ModulePath = '$PSScriptRoot\' + $ModulePath
        $null = $importScriptSb.Append('Import-Module -Name "')
        $null = $importScriptSb.Append($ModulePath)
        $null = $importScriptSb.Append('"')
        if ($spec.RequiredVersion) {
            $null = $importScriptSb.Append(' -RequiredVersion ''')
            $null = $importScriptSb.Append($spec.RequiredVersion)
            $null = $importScriptSb.Append('''')
        }
        elseif ($spec.Version) {
            $null = $importScriptSb.Append(' -Version ''')
            $null = $importScriptSb.Append($spec.Version)
            $null = $importScriptSb.Append('''')
        }
        elseif ($spec.MaximumVersion) {
            $null = $importScriptSb.Append(' -MaximumVersion ''')
            $null = $importScriptSb.Append($spec.MaximumVersion)
            $null = $importScriptSb.Append('''')
        }
        $null = $importScriptSb.AppendLine()
        $RequiredModules.Where({$_.Name -eq $spec.Name}) | ForEach-Object {
            $null = $RequiredModules.Remove($_)
        }
    }

    $importText = $importScriptSb.ToString()
    $null = New-Item -Path $importScriptPath -ItemType File -Force -ErrorAction Stop
    [IO.File]::WriteAllText($importScriptPath, $importText)
    $Manifest.ScriptsToProcess += '.\' + [IO.Path]::GetRelativePath($releasePath, $importScriptPath)
}

foreach ($required in $Manifest.RequiredModules) {
    $null = $RequiredModules.Add($required)
}

$specHashes = [List[object]]@()
foreach ($spec in $RequiredModules) {
    $hash = @{ModuleName = $spec.Name }
    $hashValid = $false
    if ($null -ne $spec.Guid) {
        $hash['Guid'] = $spec.Guid.ToString()
    }
    if ($null -ne $spec.Version) {
        $hashValid = $true
        $hash['ModuleVersion'] = $spec.Version.ToString()
    }
    if ($null -ne $spec.MaximumVersion) {
        $hashValid = $true
        $hash['MaximumVersion'] = $spec.MaximumVersion.ToString()
    }
    if ($null -ne $spec.RequiredVersion) {
        $hashValid = $true
        $hash['RequiredVersion'] = $spec.RequiredVersion.ToString()
    }
    if (!$hashValid) {
        $hash = $hash['ModuleName']
    }
    $specHashes.Add($hash)
}
$Manifest.RequiredModules = $specHashes

foreach ($required in $Manifest.RequiredAssemblies) {
    $null = $RequiredAssemblies.Add($required)
}
$Manifest.RequiredAssemblies = [string[]]$RequiredAssemblies
if ($Manifest.CompatiblePSEditions.Count -gt $CompatiblePSEditions.Count) {
    $Manifest.CompatiblePSEditions = [string[]]$CompatiblePSEditions
}
if ($null -ne $PowerShellVersion -and ($null -eq $Manifest.PowerShellVersion -or $PowerShellVersion -gt [version]$Manifest.PowerShellVersion)) {
    $Manifest.PowerShellVersion = $PowerShellVersion.ToString()
}
if ($null -eq $Manifest.CmdletsToExport) { $Manifest.CmdletsToExport = @() }
if ($null -eq $Manifest.VariablesToExport) { $Manifest.VariablesToExport = @() }
if ($null -eq $Manifest.AliasesToExport) { $Manifest.AliasesToExport = @() }

$null = New-Item -Path $releasePath -ItemType Directory -Force -ErrorAction Stop
$moduleBodyString = $moduleBodySb.ToString() -replace '(\r?\n)+$', ''
if ((Test-Path $formattingRulesPath)) {
    $moduleBodyString = Invoke-Formatter -ScriptDefinition $moduleBodyString -Settings $formattingRulesPath
}
$null = Set-Content -Path $moduleDefinition -Value $moduleBodyString -ErrorAction Stop

$entrySb = [StringBuilder]::new()
$null = ItemToString $Manifest -sb $entrySb -SortKeys
$null = New-Item -Path $moduleManifest -ItemType File -Force
$entryString = $entrySb.ToString() -replace '(\r?\n)+$', ''
if ((Test-Path $formattingRulesPath)) {
    $entryString = Invoke-Formatter -ScriptDefinition $entryString -Settings $formattingRulesPath
}
$null = Set-Content -Path $moduleManifest -Value $entryString

# Copy Modules, Assemblies, and OtherFiles to the release directory
foreach ($file in $OtherFiles) {
    $relToRelease = [IO.Path]::GetRelativePath($srcPath, $file)
    $newPath = [IO.Path]::Combine($releasePath, $relToRelease)
    $null = Copy-Item -Path $file -Destination $newPath -Force -ErrorAction Stop
}
foreach ($assembly in $AssembliesToCopy) {
    $targetFolder = [IO.Path]::GetRelativePath($ModuleRoot, $srcAssembliesPath)
    $rel = [IO.Path]::GetRelativePath($srcAssembliesPath, $assembly)
    $newDirectory = [IO.Path]::Combine($releasePath, $targetFolder)
    $newPath = [IO.Path]::Combine($newDirectory, $rel)
    $null = Copy-Item -Path $assembly -Destination $newPath -Force -ErrorAction Stop
}
foreach ($module in $ModulesToCopy) {
    $currentModule = [IO.Path]::GetFileNameWithoutExtension($module)
    $currentDir = [IO.Path]::Combine([IO.Path]::GetDirectoryName($module), $currentModule)
    $newPath = [IO.Path]::Combine($releaseModulesPath, $currentModule)
    $null = Copy-Item -Path $currentDir -Recurse -Destination $newPath -Force -ErrorAction Stop
}

$CurrentPublicFunctions = $publicFunctions.Count
if ((Get-Module -Name $ModuleName)) {
    $null = Remove-Module -Name $ModuleName -Force -ErrorAction Stop
}
try {
    $TempModule = Import-Module $releasePath -PassThru -ErrorAction Stop | Where-Object { $_.Name -eq $ModuleName }
}
catch {
    throw
}
if ($null -eq $TempModule) { return }
# Generate Proxy Functions to load into module state after classes are declared
$ModuleAssembly = & $TempModule { [AppDomain]::CurrentDomain.GetAssemblies().Where({ $_.GetCustomAttributes($false).Where({ $_.TypeId -eq [DynamicClassImplementationAssemblyAttribute] -and ($null -eq $_.ScriptFile -or $_.ScriptFile.StartsWith($releasePath)) }).Count -gt 0 }) | 
        Sort-Object -Property { [Version]($_.FullName -replace '^.*Version=([^,]+),.*$', '$1') } -Descending | Select-Object -First 1 }

$first = $true
foreach ($cmdlet in $ModuleAssembly.ExportedTypes) {
    $type = $cmdlet
    while ($type -ne [Cmdlet] -and $null -ne $type.BaseType) { $type = $type.BaseType }
    # Not a cmdlet:
    if ($type -ne [Cmdlet]) { continue }
    $CmdletAttrib = $cmdlet.GetCustomAttributes(([CmdletAttribute]), $true)
    if ($null -eq $CmdletAttrib) { Write-Warning "$($cmdlet.FullName) has no CmdletAttribute"; continue }
    $Verb = $CmdletAttrib.VerbName
    $Noun = $CmdletAttrib.NounName
    if ([string]::IsNullOrEmpty($Verb) -or [string]::IsNullOrEmpty($Noun)) {
        Write-Warning "$($cmdlet.FullName) has an invalid name: '$Verb-$Noun'"
        continue
    }
    $funcName = "$Verb-$Noun"
    if ($publicClasses.Contains($cmdlet.FullName)) {
        $null = $publicFunctions.Add($funcName)
    }
    else {
        $null = $privateFunctions.Add($funcName)
    }
    $Body = [ProxyCommand]::Create([CommandMetadata]::new($cmdlet))
    $Replacement = "`$ExecutionContext.InvokeCommand.GetCmdletByTypeName('$($cmdlet.FullName)')"
    $Definition = @"
function $funcName {
    $(($Body -split "`r?`n") -join ([Environment]::NewLine + '    '))
}
"@ -replace '\$ExecutionContext\.InvokeCommand\.GetCommand\([^\)]+\)(?=\s*(\r?\n|\$))', $Replacement

    if (!$first) { $null = $moduleBodySb.AppendLine() }
    $null = $moduleBodySb.AppendLine()
    $null = $moduleBodySb.Append('# Proxy Function Definition for ')
    $null = $moduleBodySb.Append($funcName)
    $null = $moduleBodySb.Append(' declared in Type [')
    $null = $moduleBodySb.Append($cmdlet.FullName)
    $null = $moduleBodySb.AppendLine(']')
    $null = $moduleBodySb.AppendLine($Definition)
    $first = $false
}
if (!$first) { $null = $moduleBodySb.AppendLine() }

$null = $TempModule | Remove-Module

if ($BuildType -eq 'Debug') {
    foreach ($private in $privateFunctions) {
        $null = $publicFunctions.Add($private)
    }
}

if ($CurrentPublicFunctions -lt $publicFunctions.Count) {
    # Update Manifest Again w/ any new functions
    $Manifest.FunctionsToExport = [string[]]$publicFunctions
    
    $entrySb = [StringBuilder]::new()
    $null = ItemToString $Manifest -sb $entrySb -SortKeys
    $null = New-Item -Path $moduleManifest -ItemType File -Force
    $entryString = $entrySb.ToString() -replace '(\r?\n)+$', ''
    if ((Test-Path $formattingRulesPath)) {
        $entryString = Invoke-Formatter -ScriptDefinition $entryString -Settings $formattingRulesPath
    }
    $null = Set-Content -Path $moduleManifest -Value $entryString -ErrorAction Stop
}


# Get the OnLoad Script if it exists
$onLoadEvent = ''
$onLoadPath = [IO.Path]::Combine($ModuleRoot, 'OnLoad.ps1')
if ((Test-Path -Path $onLoadPath)) {
    $parseerrors = $null
    $onLoadAst = [Parser]::ParseFile($onLoadPath, [ref] $null, [ref] $parseerrors)
    if ($parseerrors.Count -gt 0) {
        Write-Warning "Failed to parse OnRemove.ps1: $($parseerrors[0].Message)"
        return
    }
    if (![string]::IsNullOrEmpty($onLoadEvent)) {
        $onLoadEvent += "`r`n"
    }
    $onLoadEvent += $onLoadAst.Extent.Text
}

if (![string]::IsNullOrWhiteSpace($onLoadEvent)) {
    $null = $moduleBodySb.AppendLine()
    $null = $moduleBodySb.AppendLine('# OnLoad Event')
    $null = $moduleBodySb.AppendLine($onLoadEvent)
}

# Get the OnRemove Script if it exists
if ($NestedModules.Count -gt 0) {
    $onRemoveEvent = @"
(Get-Module '$ModuleName').NestedModules | Remove-Module -Force
"@
}
else {
    $onRemoveEvent = ''
}

$onRemovePath = [IO.Path]::Combine($ModuleRoot, 'OnRemove.ps1')
if ((Test-Path -Path $onRemovePath)) {
    $parseerrors = $null
    $onRemoveAst = [Parser]::ParseFile($onRemovePath, [ref] $null, [ref] $parseerrors)
    if ($parseerrors.Count -gt 0) {
        Write-Warning "Failed to parse OnRemove.ps1: $($parseerrors[0].Message)"
        return
    }
    if (![string]::IsNullOrEmpty($onRemoveEvent)) {
        $onRemoveEvent += "`r`n"
    }
    $onRemoveEvent += $onRemoveAst.Extent.Text
}

if (![string]::IsNullOrWhiteSpace($onRemoveEvent)) {
    $null = $moduleBodySb.AppendLine()
    $null = $moduleBodySb.AppendLine('# OnRemove Event Handler')
    $null = $moduleBodySb.AppendLine('$null = Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -MaxTriggerCount 1 -Action {')
    $null = $moduleBodySb.AppendLine("    (Get-Module -Name '$ModuleName').OnRemove = {")
    foreach ($line in $onRemoveEvent -split "`r?`n") {
        $null = $moduleBodySb.Append('        ')
        $null = $moduleBodySb.AppendLine($line)
    }
    $null = $moduleBodySb.AppendLine('    }')
    $null = $moduleBodySb.AppendLine('}')
}

# Update the Module Definition
$moduleBodyString = $moduleBodySb.ToString() -replace '(\r?\n)+$', ''
if ((Test-Path $formattingRulesPath)) {
    $moduleBodyString = Invoke-Formatter -ScriptDefinition $moduleBodyString -Settings $formattingRulesPath
}
$null = Set-Content -Path $moduleDefinition -Value $moduleBodyString -ErrorAction Stop

# Save file hashes to bld metadata on successful build
$null = New-Item -Path $bldMeta -ItemType File -Force

$null = $entrySb.Clear()
$null = ItemToString $buildHashes -sb $entrySb -SortKeys
$null = New-Item -Path $bldMeta -ItemType File -Force
$entryString = $entrySb.ToString() -replace '(\r?\n)+$', ''
if ((Test-Path $formattingRulesPath)) {
    $entryString = Invoke-Formatter -ScriptDefinition $entryString -Settings $formattingRulesPath
}
$null = Set-Content -Path $bldMeta -Value $entryString -ErrorAction Stop


if ($BuildType -eq 'Release') {
    $Files = Get-ChildItem -Path $releasePath | Select-Object -ExpandProperty FullName
    $null = Compress-Archive -Path $Files -DestinationPath ([IO.Path]::Combine($zipPath, "$ModuleName.zip")) -CompressionLevel Optimal -Force
}

Write-Host "Done building '$ModuleName' module."
if ($Nested) {
    return $true
}
return