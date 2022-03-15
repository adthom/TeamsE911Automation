function Get-VariableAssignment {
    param (
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.Language.VariableExpressionAst]
        $VariableAst
    )
    $VariableName = $VariableAst.VariablePath.UserPath
    $StartOffset = $VariableAst.Extent.StartOffset
    $SearchAst = $VariableAst.Parent
    while ($null -ne $SearchAst) {
        $VariableAssignmentPredicate = {
            param([System.Management.Automation.Language.Ast]$Ast)
            $returnValue = $false
            if ($Ast -is [System.Management.Automation.Language.AssignmentStatementAst]) {
                $returnValue = $true
            }
            $returnValue
        }
        
        $ClosestAssignment = $SearchAst.FindAll($VariableAssignmentPredicate, $true) |
            Where-Object { $_.Extent.StartOffset -lt $StartOffset -and $_.Left.VariablePath.UserPath -eq $VariableName } |
            Sort-Object -Property @{expression = { $_.Extent.StartOffset } } -Descending |
            Select-Object -First 1
        if ($null -ne $ClosestAssignment) {
            $ClosestAssignment
            break
        }
        $SearchAst = $SearchAst.Parent
    }
    if ($null -eq $ClosestAssignment) {
        Get-ForEachAssignment -VariableAst $VariableAst
    }
}

function Get-ForEachAssignment {
    param (
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.Language.VariableExpressionAst]
        $VariableAst
    )
    $Parent = $VariableAst.Parent
    while ($null -ne $Parent) {
        if ($Parent -is [System.Management.Automation.Language.ForEachStatementAst]) {
            $forEachAst = $Parent | 
                Where-Object { $_.Variable.Extent.StartOffset -lt $StartOffset -and $_.Variable.VariablePath.UserPath -eq $VariableName } |
                Sort-Object -Property @{expression = { $_.Extent.StartOffset } } -Descending |
                Select-Object -First 1
            if ($null -ne $forEachAst) {
                $forEachAst
                break
            }
        }
        $Parent = $Parent.Parent
    }
}

function Get-ExpressionFromStatement {
    [CmdletBinding()]
    param (
        [System.Management.Automation.Language.StatementAst]
        $StatementAst
    )
    if ($null -ne $StatementAst.Expression) {
        return $StatementAst.Expression
    }
    if (($StatementAst | Get-Member -MemberType Method -Name GetPureExpression) -and $null -ne $StatementAst.GetPureExpression()) {
        return $StatementAst.GetPureExpression()
    }
    if ($null -ne $StatementAst.Right) {
        return (Get-ExpressionFromStatement -StatementAst $StatementAst.Right)
    }
    if ($null -ne $StatementAst.Condition) {
        return (Get-ExpressionFromStatement -StatementAst $StatementAst.Condition)
    }
    Write-Warning "$($MyInvocation.MyCommand.Name) - Unhandled Statement Type ($($StatementAst.GetType().FullName))"
}

function Resolve-InvokedVariableToString {
    [CmdletBinding()]
    param (
        [System.Management.Automation.Language.Ast[]]
        $ExpressionAst
    )
    foreach ($ea in $ExpressionAst) {
        if ($ea -is [System.Management.Automation.Language.StatementBlockAst]) {
            Resolve-InvokedVariableToString -ExpressionAst $ea.Statements
            continue
        }
        $ExpressionA = if ($ea -is [System.Management.Automation.Language.StatementAst]) {
            Get-ExpressionFromStatement -StatementAst $ea
        }
        elseif ($ea -is [System.Management.Automation.Language.ExpressionAst]) {
            $ea
        }
        switch ($ExpressionA.GetType()) {
            { $_ -in @([System.Management.Automation.Language.StringConstantExpressionAst], [System.Management.Automation.Language.ConstantExpressionAst]) } {
                $ExpressionA.Value.ToString()
                break
            }
            { $_ -in @([System.Management.Automation.Language.ArrayExpressionAst], [System.Management.Automation.Language.SubExpressionAst]) } {
                Resolve-InvokedVariableToString -ExpressionAst $ExpressionA.SubExpression
                break
            }
            ([System.Management.Automation.Language.VariableExpressionAst]) {
                $reAst = Get-VariableAssignment -VariableAst $ExpressionA
                Resolve-InvokedVariableToString -ExpressionAst $reAst
                break
            }
            ([System.Management.Automation.Language.ExpandableStringExpressionAst]) {
                # string interpolation ( "$variable" )
                $BaseString = $ExpressionA.Value
                $Resolving = @($BaseString)
                foreach ($NestedAst in $ExpressionA.NestedExpressions) {
                    $regexReplace = [Regex]::Escape($NestedAst.Extent.Text)
                    $nestedResolvedStrings = Resolve-InvokedVariableToString -ExpressionAst $NestedAst
                    $tempResolving = foreach ($r in $nestedResolvedStrings) {
                        foreach ($b in $Resolving) {
                            $b -replace $regexReplace, $r
                        }
                    }
                    $Resolving = @($tempResolving | Sort-Object -Unique)
                }
                $Resolving
                break
            }
            default {
                Write-Warning "$($ExpressionA.GetType().FullName) parser not yet implemented!"
                break
            }
        }
    }
}
function GetUsedLocalFunctions {
    param (
        [ScriptBlock]
        $Script,

        [Collections.Generic.List[object]]
        $Functions = $null,

        [Collections.Generic.List[object]]
        $FoundFunctions = $null,

        # [Collections.Generic.List[object]]
        # $Types = $null,

        # [Collections.Generic.List[object]]
        # $FoundTypes = $null,

        [bool]
        $GetStrings = $true
    )
    if ($null -eq $Functions) {
        $allFunctions = Get-ChildItem -Path Function: | Where-Object {
            ([string]::IsNullOrEmpty($_.ModuleName) -or $_.ModuleName -eq $MyInvocation.MyCommand.ModuleName) `
                -and $_.HelpFile -notlike 'System.Management.Automation*.dll-Help.xml'
        }
        $Functions = [Collections.Generic.List[object]]::new()
        foreach ($func in $allFunctions) {
            $Functions.Add($func) | Out-Null
        }
    }
    $FunctionName = $Functions | Where-Object { $_.ScriptBlock -eq $Script } | Select-Object -ExpandProperty Name
    if ($null -eq $FoundFunctions) {
        $FoundFunctions = [Collections.Generic.List[object]]::new()
    }

    # if ($null -eq $Types) {
    #     $Types = [Collections.Generic.List[object]]::new()
    # }
    # if ($null -eq $FoundTypes) {
    #     $FoundTypes = [Collections.Generic.List[object]]::new()
    # }
    $AlreadyFound = $FoundFunctions | Where-Object { $_.ScriptBlock -eq $Script -and $_.Name -eq $FunctionName }
    if (!$AlreadyFound) {
        $NamedCommandPredicate = {
            param([System.Management.Automation.Language.Ast]$Ast)
            $returnValue = $false
            if ($Ast -is [System.Management.Automation.Language.CommandAst]) {
                $cmdAst = [System.Management.Automation.Language.CommandAst]$Ast
                $name = $cmdAst.GetCommandName()
                if ($null -ne $name) {
                    $returnValue = $true
                }
            }
            $returnValue
        }
    
        $newFunctions = [Collections.Generic.List[object]]::new()
        foreach ($func in $Functions) {
            if ($func.ScriptBlock -ne $Script) {
                $newFunctions.Add($func) | Out-Null
            }
        }
        $Ast = $Script.Ast
        $NamedCommandAstFound = $Ast.FindAll($NamedCommandPredicate, $true)

        # $PowershellEnumClass = [AppDomain]::CurrentDomain.GetAssemblies().ForEach({ try { $_.GetTypes() } catch {} }).Where({ $_.Module.FullyQualifiedName -eq '<In Memory Module>' -and $_.IsPublic })
        # $EnumAndClassDeclarations = $Ast.FindAll({param($Ast) $Ast -is [System.Management.Automation.Language.TypeDefinitionAst] },$true)
        # $KnownClasses = $EnumAndClassDeclarations.Name
        # this does not handle New-Object...
        # $TypeExpressions = $Ast.FindAll({param($Ast) $Ast -is [System.Management.Automation.Language.TypeExpressionAst] -and $Ast.TypeName.FullName -in $KnownClasses },$true).TypeName.FullName | Sort-Object -Unique
        # $TypeConstraints = $Ast.FindAll({param($Ast) $Ast -is [System.Management.Automation.Language.TypeConstraintAst] -and $Ast.TypeName.FullName -in $KnownClasses },$true).TypeName.FullName | Sort-Object -Unique
        # $TypesToInclude = @($TypeConstraints) + @($TypeExpressions) | Sort-Object -Unique
        # $TypesIncluded = [Collections.Generic.List[string]]::new()
        # $TypeDefinitionStrings = [Collections.Generic.List[string]]::new()
        # $TypesToIncludeS = [Collections.Generic.Stack[object]]::new()
        # foreach ($Type in $TypesToInclude) {
        #     $TypesToIncludeS.Push($Type)
        # }
        # while ($TypesToIncludeS.Count -gt 0) {
        #     $Type = $TypesToIncludeS.Pop()
        #     $Declaration = $EnumAndClassDeclarations.Where({$_.Name -eq $Type},'First',1)[0].Extent.Text
        # }

        $AmpersandInvocationPredicate = {
            param([System.Management.Automation.Language.Ast]$Ast)
            $returnValue = $false
            if ($Ast -is [System.Management.Automation.Language.CommandAst]) {
                $cmdAst = [System.Management.Automation.Language.CommandAst]$Ast
                $name = $cmdAst.GetCommandName()
                if ($null -eq $name) {
                    if ($cmdAst.InvocationOperator -eq [System.Management.Automation.Language.TokenKind]::Ampersand) {
                        $returnValue = $true
                    }
                }
            }
            $returnValue
        }
        # $Ast = $Function.ScriptBlock.Ast
        $AmpersandInvokedExpressions = $Ast.FindAll($AmpersandInvocationPredicate, $true)
        $InvokedCommandNamesFound = foreach ($aIE in $AmpersandInvokedExpressions) {
            $invoked = $aIE.CommandElements[0]
            $InvokedStrings = Resolve-InvokedVariableToString -ExpressionAst $invoked
            foreach ($invokedString in $InvokedStrings) {
                $invokedString
            }
        }
        $InvokedCommandNamesFound = $InvokedCommandNamesFound | Sort-Object -Unique | Where-Object { $_ -in $Functions.Name }
        $FoundNames = $NamedCommandAstFound | Where-Object { $null -ne $_ } | ForEach-Object { $_.GetCommandName() } | Sort-Object -Unique | Where-Object { $_ -in $Functions.Name }
        # $FoundNames += $InvokedCommandNamesFound
        $ff = $newFunctions | Where-Object { $_.Name -in $FoundNames -or $_.Name -in $InvokedCommandNamesFound }
        $usedFunctions = foreach ($func in $ff) {
            if ($func -in $FoundFunctions) {
                continue
            }
            $func
            GetUsedLocalFunctions -Script $func.ScriptBlock -Functions $newFunctions -FoundFunctions $FoundFunctions -GetStrings $false
            if (!$FoundFunctions.Contains($func)) {
                $FoundFunctions.Add($func) | Out-Null
            }
        }
        $usedFunctions = $usedFunctions | Sort-Object -Property Name -Unique
        if ($GetStrings) {
            # $TypeDefinitionStrings
            $usedFunctions | ForEach-Object { "function $($_.Name) {$([Environment]::NewLine)$($_.Definition.Trim([Environment]::NewLine))$([Environment]::NewLine)}" }
        }
        else {
            $usedFunctions
        }
    }
}
