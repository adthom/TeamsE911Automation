using namespace System.Management.Automation.Language
using namespace System.Collections.Generic

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param (
    [Parameter(Mandatory, Position = 0)]
    [string]
    $RootPath,

    [long]
    $SampleIntervalMs = 0
)

$PerfBody = [IO.File]::ReadAllText("$PSScriptRoot\PerfLogger.ps1")
$ReplaceString = '<#-# this statically AOT #-#>'
$PerfBody = $PerfBody -replace '<#-# SAMPLERATEMS #-#>', "= $SampleIntervalMs"
$MethodInfos = [List[string]]@()
$MethodId = 0

function Get-MethodInfoHashString {
    [CmdletBinding()]
    [OutputType([int])]
    param (
        [Parameter(Mandatory,Position=0)]
        [string]
        $File,
        [Parameter(Mandatory,Position=1)]
        [string]
        $Source,
        [Parameter(Mandatory,Position=2)]
        [string]
        $Method,
        [Parameter(Mandatory,Position=3)]
        [int]
        $Line
    )
    $Str = '@{{Id = {4}; Source = ''{1}''; Method = ''{2}''; File = ''{0}''; Line = {3} }}' -f $File, $Source, $Method, $Line, $Script:MethodId
    $null = $MethodInfos.Add($Str)
    $MethodId | Write-Output
    $Script:MethodId++
}

class AstReplacement {
    [int] $Start
    [int] $End
    [string] $Replacement
    [string] $Original

    [void] IncrementOffset([AstReplacement] $updated) {
        if ($updated.End -lt $updated.Start) { throw "updated.End must be greater than or equal to updated.Start $updated" }
        $Offset = $updated.OffsetChange()
        $PreStart = $this.Start
        $PreEnd = $this.End
        if ($this.Start -ge $updated.Start) {
            $this.Start += $Offset
        }
        if ($this.End -ge $updated.Start) {
            $this.End += $Offset
        }
        if ($this.End -le $this.Start) {
            Write-Warning "IncrementOffset: $Offset [${PreStart}:$PreEnd] => [$($this.Start):$($this.End)] $updated"
            throw
        }
    }
    [int] OffsetChange() {
        return $this.Replacement.Length - $this.Original.Length
    }
    static [string] UpdateAstText([Ast] $OriginalAst, [Collections.Generic.List[AstReplacement]] $Replacements) {
        $AstSB = [Text.StringBuilder]::new($OriginalAst.ToString())
        $StillToProcess = [Collections.Generic.List[AstReplacement]]::new($Replacements)
        if ($OriginalAst.Extent.StartOffset -ne 0) { 
            foreach ($still in $StillToProcess) {
                $still.Start -= $OriginalAst.Extent.StartOffset
                $still.End -= $OriginalAst.Extent.StartOffset
            }
        }
        while ($StillToProcess.Count -gt 0) {
            $CanProcess = [AstReplacement[]]$StillToProcess.Where({
                $c = $_; $s = $c.Start; $e = $c.End; $StillToProcess.Where({
                    # find overlapping items still to process
                    $_ -ne $c -and (($_.Start -le $s -and $_.End -ge $s) -or ($_.Start -le $e -and $_.End -ge $e))
                }).Count -eq 0
            })
            if ($CanProcess.Count -eq 0) { throw 'AstReplacement.UpdateAstText: $CanProcess.Count -eq 0' }
            foreach ($c in $CanProcess) {
                $c.UpdateAstText($AstSB, $StillToProcess)
                $StillToProcess.Remove($c)
            }
        }
        return $AstSB.ToString()
    }
    [void] UpdateAstText([Text.StringBuilder] $AstSB, [Collections.Generic.List[AstReplacement]] $StillToProcess) {
        $AstSB.Remove($this.Start, $this.End-$this.Start)
        $AstSB.Insert($this.Start, $this.Replacement)
        for ($i = 0; $i -lt $StillToProcess.Count; $i++) {
            $next = $StillToProcess[$i]
            if ($next -eq $this) { continue }
            $next.IncrementOffset($this)
        }
    }

    [string] ToString() {
        return "[$($this.Start):$($this.End)] $($this.Original) => $($this.Replacement)"
    }
}

function GetUnvisitedChildScriptBlocks {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [Ast]
        $ParentAst
    )
    process {
        $ScriptBlocks = $ParentAst.FindAll({ 
            param($a) $a -is [ScriptBlockAst] -and $a.Parent -isnot [ScriptBlockExpressionAst] -and $a -ne $ParentAst
        }, $true)
        $ReturnItems = [Collections.Generic.HashSet[ScriptBlockAst]]@()
        foreach ($ScriptBlock in $ScriptBlocks) {
            if ($ReturnItems.Contains($ScriptBlock)) { continue }
            if ($null -ne $ScriptBlock.EndBlock.Statements -and $ScriptBlock.EndBlock.Statements.Count -gt 0 -and 
                $ScriptBlock.EndBlock.Statements.Where({
                    $_.PipelineElements.Count -gt 0 -and
                    $_.PipelineElements.Where({
                        $_.Expression.Expression.TypeName.FullName -eq 'PerfLogger'},'First',1).Count -gt 0},'First',1).Count -gt 0) { continue }
            $Next = $ScriptBlock
            $Skip = $true
            while ($null -ne $Next.Parent) {
                if ($Next -eq $ParentAst -or $Next.Parent -eq $ParentAst) { 
                    $Skip = $false
                    break
                }
                $Next = $Next.Parent
            }
            if ($Skip) { continue }
            if ($ScriptBlock.Extent.Text.Trim('{').Trim('}').Trim().Length -eq 0) { continue }
            $Children = $ScriptBlock | GetUnvisitedChildScriptBlocks
            if ($Children.Count -eq 0) {
                $null = $ReturnItems.Add($ScriptBlock)
            }
        }
        return $ReturnItems
    }
}

function Get-ScriptBlockAstId {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [ScriptBlockAst]
        $ScriptBlockAst
    )
    begin {
        $IdSB = [Text.StringBuilder]::new()
    }
    process {
        # $null = $IdSB.Clear()
        # $Source = $ScriptBlockAst
        # while ($null -ne $Source.Parent) {
        #     $Source = $Source.Parent
        # }
        # $SourceDirectory = if (![string]::IsNullOrEmpty($Source.Extent.File)) { [IO.Path]::GetDirectoryName($Source.Extent.File) } else { '' }
        # if (![string]::IsNullOrEmpty($ScriptBlockAst.Extent.File)) {
        #     $FilePath = [IO.Path]::GetRelativePath($SourceDirectory, $ScriptBlockAst.Extent.File)
        #     $null = $IdSB.Append($FilePath)
        # }
        # else {
        #     $null = $IdSB.Append('<InMemory>')
        # }
        # $null = $IdSB.Append(':')
        # if ($null -ne $ScriptBlockAst.Parent.Parent.Parent.Name) {
        #     $null = $IdSB.Append($ScriptBlockAst.Parent.Parent.Parent.Name)
        #     $null = $IdSB.Append('.')
        # }
        # $null = $IdSB.Append($ScriptBlockAst.Parent.Name)
        # $null = $IdSB.Append('{0}:{1}')
        # # $null = $IdSB.Append($ScriptBlockAst.Extent.StartScriptPosition.LineNumber)
        # return $IdSB.ToString()
        Get-MethodInfoHashString $File $Source $Method $Line
    }
}

function Get-AstReplacement {
    [CmdletBinding()]
    [OutputType([AstReplacement])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [NamedBlockAst]
        $Block,

        [Parameter(Mandatory, Position = 0)]
        [string]
        $PreBlock,

        [Parameter(Mandatory, Position = 1)]
        [string]
        $PostBlock
    )
    begin {
        $BlockSB = [Text.StringBuilder]::new()
    }
    process {
        $Extent = $Block.Extent
        $Statements = $Block.Statements
        if ($null -ne $Statements) {  # -and $Statements[0].Expression.Member.Extent.Text -eq 'base'
            $Statements = @($Statements | Where-Object {$_.Extent.StartOffset -ge $Extent.StartOffset -and $_.Extent.EndOffset -le $Extent.EndOffset})
        }
        $Line = $Extent.StartScriptPosition.LineNumber
        $Source = $Block.Parent
        while ($null -ne $Source.Parent) {
            $Source = $Source.Parent
        }
        $SourceDirectory = if (![string]::IsNullOrEmpty($Source.Extent.File)) { [IO.Path]::GetDirectoryName($Source.Extent.File) } else { '' }
        $File = if (![string]::IsNullOrEmpty($Block.Parent.Extent.File)) {
            [IO.Path]::GetRelativePath($SourceDirectory, $Block.Parent.Extent.File)
        }
        else {
            '<InMemory>'
        }
        if ($File -eq '<InMemory>' -and $FileName -ne '<InMemory>') {
            $File = $FileName
        }
        if ($null -ne $Block.Parent.Parent.Parent.Parent.Name) {
            $Source = $Block.Parent.Parent.Parent.Parent.Name
            $Method = $Block.Parent.Parent.Name
        }
        else {
            $Source = $Block.Parent.Parent.Name
            $Method = $Block.BlockKind.ToString()
        }
        $Id = Get-MethodInfoHashString $File $Source $Method $Line
        $StartOffset = $Extent.StartOffset
        $StartColumn = $Extent.StartColumnNumber
        $EndOffset = $Extent.EndOffset
        if ($null -ne $Statements -and $Statements.Count -gt 0) {
            $StartOffset = [Math]::Max($StartOffset, $Statements[0].Extent.StartOffset)
            $StartColumn = if ($StartOffset -eq $Extent.StartOffset) { $Extent.StartColumnNumber } else { $Statements[0].Extent.StartColumnNumber }
            $EndOffset = [Math]::Min($EndOffset, $Statements[-1].Extent.EndOffset)
        }
        if ($StartOffset -eq $EndOffset -or [string]::IsNullOrWhiteSpace($Extent.Text.Substring($StartOffset-$Extent.StartOffset, $EndOffset-$StartOffset))) {
            return
        }
        # $PreBlock = $PreBlock.Replace('{0}',$BlockInfo).Replace('{1}', $Extent.StartScriptPosition.LineNumber)
        # $PostBlock = $PostBlock.Replace('{0}',$BlockInfo).Replace('{1}', $Extent.StartScriptPosition.LineNumber)
        $PreBlock = $PreBlock.Replace('{0}',$Id)
        $PostBlock = $PostBlock.Replace('{0}',$Id)
        $Spaces = [string]::new(' ', [Math]::Max(0, $StartColumn - 1))
        $null = $BlockSB.Clear()
        $null = $BlockSB.Append($Extent.Text.Substring(0,[Math]::Max(0,$StartOffset-$Extent.StartOffset)))
        $null = $BlockSB.Append($PreBlock)
        $spaceString = $Spaces + '    '
        foreach ($statement in @($Statements | Sort-Object -Property { $_.Extent.StartOffset } -Stable)) {
            $Statement.Extent.Text.Split([Environment]::NewLine).ForEach({
                $null = $BlockSB.AppendLine()
                $null = $BlockSB.Append($spaceString)
                $null = $BlockSB.Append($_)
            })
        }
        if ($Statements.Count -gt 0) {
            $null = $BlockSB.AppendLine()
            $null = $BlockSB.Append($Spaces)
        }
        $null = $BlockSB.Append($PostBlock)
        $null = $BlockSB.Append($Extent.Text.Substring($EndOffset-$Extent.StartOffset))
        [AstReplacement]@{
            Original    = $Extent.ToString()
            Replacement = $BlockSB.ToString()
            Start       = $Extent.StartOffset
            End         = $Extent.EndOffset
        } | Write-Output
    }
}

function Get-ScriptBlockReplacement {
    [CmdletBinding()]
    [OutputType([AstReplacement])]
    param (
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [ScriptBlockAst]
        $FunctionBody
    )
    begin {
        $PreSB = [Text.StringBuilder]::new()
        $PostSB = [Text.StringBuilder]::new()
    }
    process {
        # $Id = $FunctionBody | Get-ScriptBlockAstId
        $null = $PreSB.Clear()
        # $null = $PreSB.Append('[PerfLogger]::Enter(''').Append($Id).Append('''); try {')
        $null = $PreSB.Append('[PerfLogger]::Enter(').Append('{0}').Append('); try {')
        $Pre = $PreSB.ToString()

        $null = $PostSB.Clear()
        # $null = $PostSB.Append('} finally { [PerfLogger]::Exit(''').Append($Id).Append(''') }')
        $null = $PostSB.Append('} finally { [PerfLogger]::Exit(').Append('{0}').Append(') }')
        $Post = $PostSB.ToString()

        if ($null -ne $FunctionBody.BeginBlock) {
            $FunctionBody.BeginBlock | Get-AstReplacement $Pre $Post
        }
        if ($null -ne $FunctionBody.ProcessBlock) {
            $FunctionBody.ProcessBlock | Get-AstReplacement $Pre $Post
        }
        if ($null -ne $FunctionBody.EndBlock) {
            $FunctionBody.EndBlock | Get-AstReplacement $Pre $Post
        }
        if ($null -ne $FunctionBody.DynamicParamBlock) {
            $FunctionBody.DynamicParamBlock | Get-AstReplacement $Pre $Post
        }
        if ($null -ne $FunctionBody.CleanBlock) {
            $FunctionBody.CleanBlock | Get-AstReplacement $Pre $Post
        }
    }
}

function Add-PerformanceTracing {
    [CmdletBinding(DefaultParameterSetName = 'String', SupportsShouldProcess, ConfirmImpact = 'High')] 
    param (
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [string]
        $InputObject
    )
    begin {
        $Tokens = $null
        $ParserErrors = $null
    }
    process {
        $Type = ''
        if ((Test-Path -Path $InputObject -PathType Leaf)) {
            $RootAst = [Parser]::ParseFile($InputObject, [ref] $Tokens, [ref] $ParserErrors)
            $Type = 'File'
        }
        else {
            $RootAst = [Parser]::ParseInput($InputObject, [ref] $Tokens, [ref] $ParserErrors)
            $Type = 'String'
        }
        if ($ParserErrors.Count -gt 0 -and ($ParserErrors.ErrorId -eq 'TypeNotFound').Count -ne $ParserErrors.Count) {
            foreach ($ParserError in $ParserErrors) {
                Write-Warning $ParserError
            }
            throw "Parser errors found in $Type"
            return
        }

        $Ast = $RootAst
        $Children = [ScriptBlockAst[]]@($Ast | GetUnvisitedChildScriptBlocks)
        $Loop = 1
        $FileName = '<InMemory>'
        while ($Children.Count -gt 0) {
            $Child = $Children[0]
            $Extent = $Child.Extent
            if (![string]::IsNullOrEmpty($Extent.File) -and [IO.Path]::GetFileName($Extent.File) -ne $FileName -and $Extent.FileName -ne '<InMemory>') {
                $FileName = [IO.Path]::GetFileName($Extent.File)
            }
            $Replacements = [AstReplacement[]]@($Child | Get-ScriptBlockReplacement)
            $Fixed = [AstReplacement]::UpdateAstText($Child, $Replacements)
            $OriginalAstText = $Ast.Extent.Text
            $NewAstText = $OriginalAstText.Substring(0,$Extent.StartOffset) + $Fixed + $OriginalAstText.Substring($Extent.EndOffset)
            $NewAstText = $NewAstText.Replace('<InMemory>', $FileName)
            $Ast = [Parser]::ParseInput($NewAstText, [ref]$null, [ref]$null)
            $Children = [ScriptBlockAst[]]@($Ast | GetUnvisitedChildScriptBlocks)
            if ($Loop.Count -gt 10) {
                Write-Warning "$($Loop) for $($Type -eq 'File' ? $InputObject : 'ScriptBlock')"
                if ($Loop.Count -gt 100) {
                    throw "Too many loops"
                }
            }
            $Loop++
        }
        $ReplacementText = Invoke-Formatter $Ast.ToString() -Settings $PSScriptRoot\..\PSScriptAnalyzerFormattingRules.psd1
        $Ast = [Parser]::ParseInput($ReplacementText, [ref] $Tokens, [ref] $ParserErrors)
        if ($ParserErrors.Count -gt 0 -and ($ParserErrors.ErrorId -eq 'TypeNotFound').Count -ne $ParserErrors.Count) {
            foreach ($ParserError in $ParserErrors) {
                Write-Warning $ParserError
            }
            throw "Parser errors found in traced $Type"
            return
        }
        if ($Type -eq 'File') {
            $NewPath = [IO.Path]::Combine([IO.Path]::GetDirectoryName($InputObject),[IO.Path]::GetFileNameWithoutExtension($InputObject) + '.traced' + [IO.Path]::GetExtension($InputObject))
            if ($PSCmdlet.ShouldProcess($NewPath, 'Add Performance Tracing To File')) {
                [IO.File]::WriteAllText($NewPath, $ReplacementText)
                return
            }
        }
        $ReplacementText
    }
}

# function Add-PerformanceTracing {
#     [CmdletBinding(DefaultParameterSetName = 'String', SupportsShouldProcess, ConfirmImpact = 'High')] 
#     param (
#         [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
#         [string]
#         $InputObject
#     )
#     begin {
#         $Tokens = $null
#         $ParserErrors = $null
#     }
#     process {
#         $Type = ''
#         if ((Test-Path -Path $InputObject -PathType Leaf)) {
#             $Ast = [Parser]::ParseFile($InputObject, [ref] $Tokens, [ref] $ParserErrors)
#             $Type = 'File'
#         }
#         else {
#             $Ast = [Parser]::ParseInput($InputObject, [ref] $Tokens, [ref] $ParserErrors)
#             $Type = 'String'
#         }
#         if ($ParserErrors.Count -gt 0 -and ($ParserErrors.ErrorId -eq 'TypeNotFound').Count -ne $ParserErrors.Count) {
#             foreach ($ParserError in $ParserErrors) {
#                 Write-Warning $ParserError
#             }
#             throw "Parser errors found in $Type"
#             return
#         }
#         $Replacements = [AstReplacement[]]@($Ast | Get-ScriptBlockDefinition | Get-ScriptBlockReplacement)
#         $ReplacementText = [AstReplacement]::UpdateAstText($Ast, $Replacements)
#         $Ast = [Parser]::ParseInput($ReplacementText, [ref] $Tokens, [ref] $ParserErrors)
#         if ($ParserErrors.Count -gt 0 -and ($ParserErrors.ErrorId -eq 'TypeNotFound').Count -ne $ParserErrors.Count) {
#             foreach ($ParserError in $ParserErrors) {
#                 Write-Warning $ParserError
#             }
#             throw "Parser errors found in traced $Type"
#             return
#         }
#         if ($Type -eq 'File') {
#             $NewPath = [IO.Path]::Combine([IO.Path]::GetDirectoryName($InputObject),[IO.Path]::GetFileNameWithoutExtension($InputObject) + '.traced' + [IO.Path]::GetExtension($InputObject))
#             if ($PSCmdlet.ShouldProcess($NewPath, 'Add Performance Tracing To File')) {
#                 [IO.File]::WriteAllText($NewPath, $ReplacementText)
#                 return
#             }
#         }
#         $ReplacementText
#     }
# }

# function Get-ScriptBlockDefinition {
#     [CmdletBinding()]
#     param (
#         [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
#         [Ast]
#         $Ast,
#         [switch]
#         $IncludeSelf
#     )
#     process {
#         $ScriptBlocks = $Ast.FindAll({ param($a) $a -is [ScriptBlockAst] }, $true).Where({ ($IncludeSelf -or $_ -ne $Ast) -and $_.Parent -isnot [ScriptBlockExpressionAst] })
#         foreach ($ScriptBlock in $ScriptBlocks) {
#             $Next = $ScriptBlock
#             $Skip = $false
#             while ($null -ne $Next.Parent) {
#                 if ($Next -is [TypeDefinitionAst] -and 
#                     ($Next.TypeAttributes -band [TypeAttributes]::Class) -eq [TypeAttributes]::Class -and 
#                     $Next.Name -eq 'PerfLogger') {
#                     $Skip = $true
#                     break
#                 }
#                 $Next = $Next.Parent
#             }
#             if ($Skip) { continue }
#             $ScriptBlock
#         }
#     }
# }

# function Get-ClassDefinition {
#     [CmdletBinding()]
#     param (
#         [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
#         [Ast]
#         $Ast
#     )
#     process {
#         $Ast.FindAll({ param([Ast] $a) $a -is [TypeDefinitionAst] -and ($a.TypeAttributes -band [TypeAttributes]::Class) -eq [TypeAttributes]::Class }, $true)
#     }
# }

# function Get-MemberDefinition {
#     [CmdletBinding()]
#     param (
#         [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
#         [Ast]
#         $Ast
#     )
#     process {
#         $Ast.FindAll({ param($a) $a -is [FunctionMemberAst] }, $true)
#     }
# }

# function Get-FunctionDefinition {
#     [CmdletBinding()]
#     param (
#         [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
#         [Ast]
#         $Ast
#     )
#     process {
#         $Ast.FindAll({ param($a) $a -is [FunctionDefinitionAst] }, $true)
#     }
# }

$Files = Get-ChildItem -Path $RootPath -Filter '*.ps1' -File -Recurse | Where-Object { !$_.BaseName.EndsWith('.traced') } | Select-Object -ExpandProperty FullName

$Files | Add-PerformanceTracing

if ($Files.Count -gt 0) {
    $PathParts = (Resolve-Path $RootPath).Path.Split([IO.Path]::DirectorySeparatorChar)
    [Array]::Reverse($PathParts)
    $PathParts = $PathParts[$PathParts.IndexOf('src')..($PathParts.Count-1)]
    [Array]::Reverse($PathParts)
    $RootModulePath = $PathParts -join [IO.Path]::DirectorySeparatorChar
    Write-Host "Final $RootModulePath"
    $PerfLoggerPath = [IO.Path]::Combine($RootModulePath, 'PerfLogger.traced.ps1')
    if ($PSCmdlet.ShouldProcess($PerfLoggerPath, 'Create')) {
        $PerfBodyFormatted = $PerfBody.Replace($ReplaceString, "$([Environment]::NewLine)        $($MethodInfos -join ",$([Environment]::NewLine)        ")    $([Environment]::NewLine)")
        $null = New-Item -Path $PerfLoggerPath -ItemType File -Force
        [System.IO.File]::WriteAllText($PerfLoggerPath, $PerfBodyFormatted)
        & "$PSScriptRoot\..\build\build.ps1" -BuildType Trace
    }
}